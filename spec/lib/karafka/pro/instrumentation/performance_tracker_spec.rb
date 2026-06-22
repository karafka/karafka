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
  let(:tracker) { Karafka::Pro::Instrumentation::PerformanceTracker.instance }

  let(:m_class) { Karafka::Messages::Messages }
  let(:c_class) { Karafka::BaseConsumer }

  describe "#processing_time_p95 and #on_consumer_consumed" do
    let(:p95) { tracker.processing_time_p95(topic, partition) }
    let(:event) { Karafka::Core::Monitoring::Event.new(rand.to_s, payload) }

    context "when given topic does not exist" do
      let(:topic) { SecureRandom.hex(6) }
      let(:partition) { 0 }

      it { expect(p95).to eq(0) }
    end

    context "when topic exists but not the partition" do
      let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
      let(:messages) { instance_double(m_class, metadata: message.metadata, size: 12) }
      let(:payload) { { caller: instance_double(c_class, messages: messages), time: 200 } }
      let(:topic) { message.metadata.topic }
      let(:partition) { 1 }

      before { tracker.on_consumer_consumed(event) }

      it { expect(p95).to eq(0) }
    end

    context "when topic and partition exist" do
      context "when there is only one value" do
        let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
        let(:messages) { instance_double(m_class, metadata: message.metadata, size: 1) }
        let(:payload) { { caller: instance_double(c_class, messages: messages), time: 20 } }
        let(:topic) { message.metadata.topic }
        let(:partition) { 0 }

        before { tracker.on_consumer_consumed(event) }

        it { expect(p95).to eq(20) }
      end

      context "when there are more values for a give partition" do
        let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
        let(:messages) { instance_double(m_class, metadata: message.metadata, size: 1) }
        let(:payload) { { caller: instance_double(c_class, messages: messages), time: 20 } }
        let(:topic) { message.metadata.topic }
        let(:partition) { 0 }

        before do
          100.times do |i|
            payload[:time] = i % 10
            tracker.on_consumer_consumed(event)
          end
        end

        it { expect(p95).to eq(9) }
      end
    end
  end

  describe "#on_rebalance_partitions_revoked" do
    let(:times) { tracker.instance_variable_get(:@processing_times) }

    def consume(topic, partition)
      metadata = build(:messages_metadata, topic: topic, partition: partition)
      message = build(:messages_message, metadata: metadata)
      messages = instance_double(m_class, metadata: message.metadata, size: 1)
      payload = { caller: instance_double(c_class, messages: messages), time: 20 }
      tracker.on_consumer_consumed(Karafka::Core::Monitoring::Event.new(rand.to_s, payload))
    end

    def revoke(topic, *partition_ids)
      tpl = Rdkafka::Consumer::TopicPartitionList.new
      tpl.add_topic(topic, partition_ids)
      tracker.on_rebalance_partitions_revoked(
        Karafka::Core::Monitoring::Event.new(rand.to_s, { tpl: tpl })
      )
    end

    context "when the revoked partition was the only one tracked for its topic" do
      let(:topic) { SecureRandom.hex(6) }

      before { consume(topic, 0) }

      it "drops the topic entry entirely" do
        expect(times.key?(topic)).to be(true)
        revoke(topic, 0)
        expect(times.key?(topic)).to be(false)
      end
    end

    context "when the topic still has other tracked partitions" do
      let(:topic) { SecureRandom.hex(6) }

      before do
        consume(topic, 0)
        consume(topic, 1)
      end

      it "evicts only the revoked partition and keeps the topic" do
        revoke(topic, 0)
        expect(times.key?(topic)).to be(true)
        expect(times[topic].key?(0)).to be(false)
        expect(times[topic].key?(1)).to be(true)
      end
    end

    context "when the revoked topic was never tracked" do
      let(:topic) { SecureRandom.hex(6) }

      it "does not auto-vivify an entry for it" do
        revoke(topic, 0)
        expect(times.key?(topic)).to be(false)
      end
    end
  end

  describe "events mapping" do
    it { expect(NotificationsChecker.valid?(tracker)).to be(true) }
  end
end
