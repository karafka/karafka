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

      it "instruments the error with a dedicated type" do
        refresher.on_client_events_poll(event)
        next_tick

        expect(Karafka.monitor)
          .to receive(:instrument)
          .with(
            "error.occurred",
            hash_including(type: "paused_lags.refresher.error")
          )

        refresher.on_client_events_poll(event)
      end
    end

    context "when the process is done" do
      before { allow(Karafka::App).to receive(:done?).and_return(true) }

      it "does not query nor store anything" do
        refresher.on_client_events_poll(event)
        next_tick
        refresher.on_client_events_poll(event)

        expect(registry.fetch(client_name, 1_000)).to be_nil
      end
    end

    context "when a previously refreshed partition resumes" do
      it "evicts its data on the next due tick" do
        refresher.on_client_events_poll(event)
        next_tick
        refresher.on_client_events_poll(event)

        expect(registry.fetch(client_name, 1_000)).not_to be_nil

        allow(client).to receive(:paused).and_return({})
        next_tick
        refresher.on_client_events_poll(event)

        expect(registry.fetch(client_name, 1_000)).to be_nil
      end
    end

    context "when there was a failure followed by a tick with nothing long-paused" do
      before { allow(client).to receive(:committed).and_raise(StandardError) }

      it "resets the failures counter" do
        refresher.on_client_events_poll(event)
        next_tick
        refresher.on_client_events_poll(event)

        allow(client).to receive(:paused).and_return({})
        # First failure backoff is 2x the 1ms interval, so this makes the next tick due
        next_tick
        refresher.on_client_events_poll(event)

        state = refresher.instance_variable_get(:@states).fetch(sg_id)

        expect(state.fetch(:failures)).to eq(0)
      end
    end

    context "when more partitions are long-paused than the per tick cap" do
      let(:partitions) { (0...25).to_a }
      let(:paused) { { "topic" => partitions } }

      let(:committed_tpl) do
        instance_double(Rdkafka::Consumer::TopicPartitionList).tap do |tpl|
          allow(tpl).to receive(:to_h) do
            { "topic" => @last_tpl_partitions.map { |p| committed_partition_for(p) } }
          end
        end
      end

      before do
        allow(client).to receive(:committed) do |tpl|
          @last_tpl_partitions = tpl.to_h.fetch("topic").map(&:partition)
          committed_tpl
        end
      end

      def committed_partition_for(partition)
        instance_double(Rdkafka::Consumer::Partition, partition: partition, offset: 5)
      end

      it "caps a single tick and covers the remainder on the following ticks" do
        refresher.on_client_events_poll(event)
        next_tick
        refresher.on_client_events_poll(event)

        stored = registry.fetch(client_name, 1_000).fetch("topic")

        expect(stored.size).to eq(20)

        next_tick
        refresher.on_client_events_poll(event)

        stored = registry.fetch(client_name, 1_000).fetch("topic")

        expect(stored.size).to eq(25)
        expect(stored.keys.sort).to eq(partitions)
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
