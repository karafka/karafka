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
    let(:group_id) { SecureRandom.hex(6) }
    let(:p95) { tracker.processing_time_p95(group_id, topic, partition) }
    let(:event) { Karafka::Core::Monitoring::Event.new(rand.to_s, payload) }
    let(:sub_group) { instance_double(Karafka::Routing::SubscriptionGroup, id: group_id) }
    let(:c_topic) { instance_double(Karafka::Routing::Topic, subscription_group: sub_group) }

    context "when given topic does not exist" do
      let(:topic) { SecureRandom.hex(6) }
      let(:partition) { 0 }

      it { expect(p95).to eq(0) }
    end

    context "when topic exists but not the partition" do
      let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
      let(:messages) { instance_double(m_class, metadata: message.metadata, size: 12) }
      let(:payload) do
        { caller: instance_double(c_class, messages: messages, topic: c_topic), time: 200 }
      end
      let(:topic) { message.metadata.topic }
      let(:partition) { 1 }

      before { tracker.on_consumer_consumed(event) }

      it { expect(p95).to eq(0) }
    end

    context "when topic and partition exist" do
      context "when there is only one value" do
        let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
        let(:messages) { instance_double(m_class, metadata: message.metadata, size: 1) }
        let(:payload) do
          { caller: instance_double(c_class, messages: messages, topic: c_topic), time: 20 }
        end
        let(:topic) { message.metadata.topic }
        let(:partition) { 0 }

        before { tracker.on_consumer_consumed(event) }

        it { expect(p95).to eq(20) }
      end

      context "when there are more values for a give partition" do
        let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
        let(:messages) { instance_double(m_class, metadata: message.metadata, size: 1) }
        let(:payload) do
          { caller: instance_double(c_class, messages: messages, topic: c_topic), time: 20 }
        end
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

    context "when two subscription groups consume the same topic partition" do
      let(:other_group_id) { SecureRandom.hex(6) }
      let(:other_sub_group) do
        instance_double(Karafka::Routing::SubscriptionGroup, id: other_group_id)
      end
      let(:other_topic) { instance_double(Karafka::Routing::Topic, subscription_group: other_sub_group) }
      let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
      let(:messages) { instance_double(m_class, metadata: message.metadata, size: 1) }
      let(:topic) { message.metadata.topic }
      let(:partition) { 0 }

      before do
        consumed = lambda do |c_topic_double, time|
          payload = { caller: instance_double(c_class, messages: messages, topic: c_topic_double), time: time }
          tracker.on_consumer_consumed(Karafka::Core::Monitoring::Event.new(rand.to_s, payload))
        end

        consumed.call(c_topic, 10)
        consumed.call(other_topic, 50)
      end

      it "keeps independent samples per subscription group" do
        expect(tracker.processing_time_p95(group_id, topic, partition)).to eq(10)
        expect(tracker.processing_time_p95(other_group_id, topic, partition)).to eq(50)
      end
    end
  end

  describe "#on_rebalance_partitions_revoked" do
    let(:group_id) { SecureRandom.hex(6) }
    let(:times) { tracker.instance_variable_get(:@processing_times) }

    # Reads the tracked entry without auto-vivifying the default-proc hashes
    def tracked?(group_id, topic, partition = :__any__)
      group = times.fetch(group_id, nil)
      return false unless group

      topic_times = group.fetch(topic, nil)
      return false unless topic_times

      (partition == :__any__) ? true : topic_times.key?(partition)
    end

    def consume(group_id, topic, partition)
      metadata = build(:messages_metadata, topic: topic, partition: partition)
      message = build(:messages_message, metadata: metadata)
      messages = instance_double(m_class, metadata: message.metadata, size: 1)
      sub_group = instance_double(Karafka::Routing::SubscriptionGroup, id: group_id)
      c_topic = instance_double(Karafka::Routing::Topic, subscription_group: sub_group)
      payload = { caller: instance_double(c_class, messages: messages, topic: c_topic), time: 20 }
      tracker.on_consumer_consumed(Karafka::Core::Monitoring::Event.new(rand.to_s, payload))
    end

    def revoke(group_id, topic, *partition_ids)
      tpl = Rdkafka::Consumer::TopicPartitionList.new
      tpl.add_topic(topic, partition_ids)
      tracker.on_rebalance_partitions_revoked(
        Karafka::Core::Monitoring::Event.new(
          rand.to_s,
          { subscription_group_id: group_id, tpl: tpl }
        )
      )
    end

    context "when the revoked partition was the only one tracked for its topic" do
      let(:topic) { SecureRandom.hex(6) }

      before { consume(group_id, topic, 0) }

      it "drops the topic entry entirely" do
        expect(tracked?(group_id, topic)).to be(true)
        revoke(group_id, topic, 0)
        expect(tracked?(group_id, topic)).to be(false)
      end
    end

    context "when the topic still has other tracked partitions" do
      let(:topic) { SecureRandom.hex(6) }

      before do
        consume(group_id, topic, 0)
        consume(group_id, topic, 1)
      end

      it "evicts only the revoked partition and keeps the topic" do
        revoke(group_id, topic, 0)
        expect(tracked?(group_id, topic)).to be(true)
        expect(tracked?(group_id, topic, 0)).to be(false)
        expect(tracked?(group_id, topic, 1)).to be(true)
      end
    end

    context "when the revoked group was never tracked" do
      let(:topic) { SecureRandom.hex(6) }

      it "does not auto-vivify an entry for it" do
        revoke(group_id, topic, 0)
        expect(times.key?(group_id)).to be(false)
      end
    end

    context "when another subscription group consumes the same topic partition" do
      let(:other_group_id) { SecureRandom.hex(6) }
      let(:topic) { SecureRandom.hex(6) }

      before do
        consume(group_id, topic, 0)
        consume(other_group_id, topic, 0)
      end

      it "evicts only the revoked group and leaves the other group untouched" do
        revoke(group_id, topic, 0)
        expect(tracked?(group_id, topic, 0)).to be(false)
        expect(tracked?(other_group_id, topic, 0)).to be(true)
      end
    end
  end

  describe "events mapping" do
    it { expect(NotificationsChecker.valid?(tracker)).to be(true) }
  end
end
