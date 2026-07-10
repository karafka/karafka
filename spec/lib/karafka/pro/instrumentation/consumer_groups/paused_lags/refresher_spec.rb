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
  let(:registry) { Karafka::Pro::Instrumentation::ConsumerGroups::PausedLags::Registry.instance }
  let(:subscription_group) { instance_double(Karafka::Routing::SubscriptionGroup, id: sg_id) }

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
      committed: committed_tpl
    )
  end

  let(:tick_event) do
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

  before do
    Karafka::App.config.internal.statistics.consumer_groups.paused_refresh.interval = 1

    allow(Karafka::Admin::Topics)
      .to receive(:read_watermark_offsets)
      .and_return("topic" => { 0 => [1, 100], 1 => [1, 100] })
  end

  after do
    Karafka::App.config.internal.statistics.consumer_groups.paused_refresh.interval = 0
    registry.evict(client_name)
  end

  def pause_event(topic: "topic", partition: 0)
    Karafka::Core::Monitoring::Event.new(
      "client.pause",
      caller: client,
      subscription_group: subscription_group,
      topic: topic,
      partition: partition
    )
  end

  def resume_event(topic: "topic", partition: 0)
    Karafka::Core::Monitoring::Event.new(
      "client.resume",
      caller: client,
      subscription_group: subscription_group,
      topic: topic,
      partition: partition
    )
  end

  # Interval is 1ms in these specs, so a tiny sleep exceeds both the pause age threshold and
  # makes the next tick due
  def age_pause
    sleep(0.005)
  end

  describe "#on_client_events_poll" do
    context "when nothing is paused" do
      it "does not store anything" do
        refresher.on_client_events_poll(tick_event)

        expect(registry.fetch(client_name)).to be_nil
      end
    end

    context "when a partition was paused for less than the interval" do
      it "does not store anything" do
        # First tick makes the follow-up tick due-gated, so age the state first
        refresher.on_client_events_poll(tick_event)
        age_pause

        refresher.on_client_pause(pause_event)
        refresher.on_client_events_poll(tick_event)

        expect(registry.fetch(client_name)).to be_nil
      end
    end

    context "when a partition stayed paused for at least the interval" do
      it "queries and stores refreshed data" do
        refresher.on_client_pause(pause_event)
        age_pause
        refresher.on_client_events_poll(tick_event)

        expect(registry.fetch(client_name)).to eq(
          "topic" => { 0 => { lo_offset: 1, hi_offset: 100, committed_offset: 5 } }
        )
      end
    end

    context "when the refresh is not due yet" do
      before { Karafka::App.config.internal.statistics.consumer_groups.paused_refresh.interval = 10_000 }

      it "does not store anything despite a long-paused partition" do
        refresher.on_client_pause(pause_event)

        # Backdate the pause so it qualifies as long-paused despite the large interval
        state = refresher.instance_variable_get(:@states).fetch(sg_id)
        state[:paused]["topic"][0] -= 20_000

        refresher.on_client_events_poll(tick_event)

        expect(registry.fetch(client_name)).not_to be_nil

        registry.evict(client_name)

        # Immediate follow-up tick is within the interval window and must do nothing
        refresher.on_client_events_poll(tick_event)

        expect(registry.fetch(client_name)).to be_nil
      end
    end

    context "when committed offset is not present" do
      let(:committed_partition) do
        instance_double(Rdkafka::Consumer::Partition, partition: 0, offset: nil)
      end

      it "stores -1 as the committed offset" do
        refresher.on_client_pause(pause_event)
        age_pause
        refresher.on_client_events_poll(tick_event)

        expect(registry.fetch(client_name)).to eq(
          "topic" => { 0 => { lo_offset: 1, hi_offset: 100, committed_offset: -1 } }
        )
      end
    end

    context "when querying fails" do
      before { allow(client).to receive(:committed).and_raise(StandardError) }

      it "does not raise and does not store anything" do
        refresher.on_client_pause(pause_event)
        age_pause

        expect { refresher.on_client_events_poll(tick_event) }.not_to raise_error
        expect(registry.fetch(client_name)).to be_nil
      end

      it "instruments the error with a dedicated type" do
        refresher.on_client_pause(pause_event)
        age_pause

        expect(Karafka.monitor)
          .to receive(:instrument)
          .with(
            "error.occurred",
            hash_including(type: "paused_lags.refresher.error")
          )

        refresher.on_client_events_poll(tick_event)
      end
    end

    context "when the process is done" do
      before { allow(Karafka::App).to receive(:done?).and_return(true) }

      it "does not query nor store anything" do
        refresher.on_client_pause(pause_event)
        age_pause
        refresher.on_client_events_poll(tick_event)

        expect(registry.fetch(client_name)).to be_nil
      end
    end
  end

  describe "#on_client_resume" do
    it "stops tracking and drops refreshed data of the resumed partition immediately" do
      refresher.on_client_pause(pause_event)
      age_pause
      refresher.on_client_events_poll(tick_event)

      expect(registry.fetch(client_name)).not_to be_nil

      refresher.on_client_resume(resume_event)

      expect(registry.fetch(client_name)).to be_nil
    end

    it "keeps data of other partitions that remain paused" do
      refresher.on_client_pause(pause_event(partition: 0))
      refresher.on_client_pause(pause_event(partition: 1))
      age_pause

      allow(committed_tpl).to receive(:to_h).and_return(
        "topic" => [
          instance_double(Rdkafka::Consumer::Partition, partition: 0, offset: 5),
          instance_double(Rdkafka::Consumer::Partition, partition: 1, offset: 7)
        ]
      )

      refresher.on_client_events_poll(tick_event)
      refresher.on_client_resume(resume_event(partition: 0))

      expect(registry.fetch(client_name)).to eq(
        "topic" => { 1 => { lo_offset: 1, hi_offset: 100, committed_offset: 7 } }
      )
    end

    it "does not raise when the partition was not tracked" do
      expect { refresher.on_client_resume(resume_event) }.not_to raise_error
    end
  end

  describe "#on_rebalance_partitions_revoked" do
    it "evicts stored data and stops tracking all pauses" do
      refresher.on_client_pause(pause_event)
      age_pause
      refresher.on_client_events_poll(tick_event)

      expect(registry.fetch(client_name)).not_to be_nil

      refresher.on_rebalance_partitions_revoked(revocation_event)

      expect(registry.fetch(client_name)).to be_nil

      # Without new pause events, nothing must be refreshed again even after aging
      age_pause
      refresher.on_client_events_poll(tick_event)

      expect(registry.fetch(client_name)).to be_nil
    end

    it "does not raise when nothing was tracked for a given subscription group" do
      expect { refresher.on_rebalance_partitions_revoked(revocation_event) }.not_to raise_error
    end
  end
end
