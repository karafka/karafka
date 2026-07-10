# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:refresher) { described_class.new }

  let(:client_name) { SecureRandom.hex(6) }
  let(:sg_id) { SecureRandom.hex(6) }
  let(:registry) { Karafka::Pro::Instrumentation::PausedLags::Registry.instance }
  let(:subscription_group) { instance_double(Karafka::Routing::SubscriptionGroup, id: sg_id) }
  let(:paused) { { "topic" => [0] } }

  let(:committed_partition) do
    instance_double(Rdkafka::Consumer::Partition, partition: 0, offset: 5)
  end

  let(:committed_tpl) do
    instance_double(
      Rdkafka::Consumer::TopicPartitionList,
      to_h: { "topic" => [committed_partition] }
    )
  end

  let(:client) do
    instance_double(
      Karafka::Connection::Client,
      name: client_name,
      paused: paused,
      committed: committed_tpl,
      query_watermark_offsets: [1, 100]
    )
  end

  let(:event) do
    Karafka::Core::Monitoring::Event.new(
      "client.events_poll",
      caller: client,
      subscription_group: subscription_group
    )
  end

  let(:revocation_event) do
    Karafka::Core::Monitoring::Event.new(
      "rebalance.partitions_revoked",
      subscription_group: subscription_group
    )
  end

  before { Karafka::App.config.internal.statistics.paused_refresh.interval = 1 }

  after do
    Karafka::App.config.internal.statistics.paused_refresh.interval = 0
    registry.evict(client_name)
  end

  # Interval is 1ms in these specs, so a tiny sleep makes the next tick due
  def next_tick
    sleep(0.005)
  end

  describe "#on_client_events_poll" do
    context "when a partition is paused only during a single tick" do
      it "does not store anything" do
        refresher.on_client_events_poll(event)

        expect(registry.fetch(client_name, 1_000)).to be_nil
      end
    end

    context "when a partition is paused during two consecutive ticks" do
      it "queries and stores refreshed data" do
        refresher.on_client_events_poll(event)
        next_tick
        refresher.on_client_events_poll(event)

        expect(registry.fetch(client_name, 1_000)).to eq(
          "topic" => { 0 => { lo_offset: 1, hi_offset: 100, committed_offset: 5 } }
        )
      end
    end

    context "when a partition is no longer paused on the second tick" do
      it "does not store anything" do
        refresher.on_client_events_poll(event)
        next_tick

        allow(client).to receive(:paused).and_return({})
        refresher.on_client_events_poll(event)

        expect(registry.fetch(client_name, 1_000)).to be_nil
      end
    end

    context "when the refresh is not due yet" do
      it "does not store anything despite two paused observations" do
        refresher.on_client_events_poll(event)
        # Immediate second call - not due (no sleep between the calls)
        refresher.on_client_events_poll(event)

        expect(registry.fetch(client_name, 1_000)).to be_nil
      end
    end

    context "when committed offset is not present" do
      let(:committed_partition) do
        instance_double(Rdkafka::Consumer::Partition, partition: 0, offset: nil)
      end

      it "stores -1 as the committed offset" do
        refresher.on_client_events_poll(event)
        next_tick
        refresher.on_client_events_poll(event)

        expect(registry.fetch(client_name, 1_000)).to eq(
          "topic" => { 0 => { lo_offset: 1, hi_offset: 100, committed_offset: -1 } }
        )
      end
    end

    context "when querying fails" do
      before { allow(client).to receive(:committed).and_raise(StandardError) }

      it "does not raise and does not store anything" do
        refresher.on_client_events_poll(event)
        next_tick

        expect { refresher.on_client_events_poll(event) }.not_to raise_error
        expect(registry.fetch(client_name, 1_000)).to be_nil
      end
    end
  end

  describe "#on_rebalance_partitions_revoked" do
    it "evicts stored data and resets pause tracking" do
      refresher.on_client_events_poll(event)
      next_tick
      refresher.on_client_events_poll(event)

      expect(registry.fetch(client_name, 1_000)).not_to be_nil

      refresher.on_rebalance_partitions_revoked(revocation_event)

      expect(registry.fetch(client_name, 1_000)).to be_nil

      # After revocation the pause tracking restarts, so a single tick must not store again
      next_tick
      refresher.on_client_events_poll(event)

      expect(registry.fetch(client_name, 1_000)).to be_nil
    end

    it "does not raise when nothing was tracked for a given subscription group" do
      expect { refresher.on_rebalance_partitions_revoked(revocation_event) }.not_to raise_error
    end
  end
end
