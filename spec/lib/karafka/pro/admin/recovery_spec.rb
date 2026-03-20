# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:recovery) { described_class }

  let(:consumer_group_id) { SecureRandom.uuid }
  let(:topic) { generate_topic_name }

  before { Karafka::Admin.create_topic(topic, 2, 1) }

  describe ".read_committed_offsets" do
    context "when consumer group has no committed offsets" do
      it { expect(recovery.read_committed_offsets(consumer_group_id)).to eq({}) }
    end

    context "when consumer group has committed offsets for multiple topics and partitions" do
      let(:topic2) { generate_topic_name }

      let(:offsets) do
        {
          topic => { 0 => 100, 1 => 200 },
          topic2 => { 0 => 50 }
        }
      end

      before do
        Karafka::Admin.create_topic(topic2, 1, 1)
        Karafka::Admin::ConsumerGroups.seek(consumer_group_id, offsets)
      end

      it "returns committed offsets grouped by topic and partition" do
        result = recovery.read_committed_offsets(consumer_group_id)
        expect(result[topic]).to eq({ 0 => 100, 1 => 200 })
        expect(result[topic2]).to eq({ 0 => 50 })
      end

      it "returns topics sorted alphabetically" do
        result = recovery.read_committed_offsets(consumer_group_id)
        expect(result.keys).to eq(result.keys.sort)
      end

      it "returns partitions sorted numerically within each topic" do
        result = recovery.read_committed_offsets(consumer_group_id)

        result.each_value do |partitions|
          expect(partitions.keys).to eq(partitions.keys.sort)
        end
      end
    end

    context "when offsets are committed multiple times for the same partition" do
      before do
        Karafka::Admin::ConsumerGroups.seek(consumer_group_id, { topic => { 0 => 100 } })
        Karafka::Admin::ConsumerGroups.seek(consumer_group_id, { topic => { 0 => 150 } })
      end

      it "keeps the latest offset (last write wins)" do
        result = recovery.read_committed_offsets(consumer_group_id)
        expect(result[topic][0]).to eq(150)
      end
    end

    context "when offsets exist only for a single partition out of many" do
      before do
        Karafka::Admin::ConsumerGroups.seek(consumer_group_id, { topic => { 1 => 42 } })
      end

      it "returns only the partition that has committed offsets" do
        result = recovery.read_committed_offsets(consumer_group_id)
        expect(result[topic]).to eq({ 1 => 42 })
        expect(result[topic].key?(0)).to be(false)
      end
    end

    context "when another consumer group has offsets for the same topic" do
      let(:other_group_id) { SecureRandom.uuid }

      before do
        Karafka::Admin::ConsumerGroups.seek(other_group_id, { topic => { 0 => 999 } })
        Karafka::Admin::ConsumerGroups.seek(consumer_group_id, { topic => { 0 => 10 } })
      end

      it "returns only offsets for the requested consumer group" do
        result = recovery.read_committed_offsets(consumer_group_id)
        expect(result[topic][0]).to eq(10)
      end
    end

    context "when offset is 0" do
      before do
        Karafka::Admin::ConsumerGroups.seek(consumer_group_id, { topic => { 0 => 0 } })
      end

      it "returns zero offset correctly" do
        result = recovery.read_committed_offsets(consumer_group_id)
        expect(result[topic][0]).to eq(0)
      end
    end
  end

  describe ".offsets_partition_for" do
    let(:partition_count) { described_class.new.send(:offsets_partition_count) }

    it "returns a value within the partition range" do
      result = recovery.offsets_partition_for(consumer_group_id)
      expect(result).to be >= 0
      expect(result).to be < partition_count
    end

    it "is deterministic for the same consumer group id" do
      first_call = recovery.offsets_partition_for("my-group")
      second_call = recovery.offsets_partition_for("my-group")
      expect(first_call).to eq(second_call)
    end

    it "returns 0 for an empty string (Java hashCode of empty string is 0)" do
      expect(recovery.offsets_partition_for("")).to eq(0)
    end

    it "matches Java hashCode for a single character" do
      # Java: "a".hashCode() = 97, abs(97) % partition_count
      expect(recovery.offsets_partition_for("a")).to eq(97 % partition_count)
    end

    it "matches Java hashCode for strings with positive hash" do
      # Java: "test".hashCode() = 3556498
      expect(recovery.offsets_partition_for("test")).to eq(3_556_498 % partition_count)
      # Java: "hello".hashCode() = 99162322
      expect(recovery.offsets_partition_for("hello")).to eq(99_162_322 % partition_count)
    end

    it "matches Java hashCode for strings with negative hash" do
      # Java: "polarbear".hashCode() = -441539598, abs = 441539598
      expect(recovery.offsets_partition_for("polarbear")).to eq(441_539_598 % partition_count)
      # Java: "my-app-group".hashCode() = -1350864654, abs = 1350864654
      expect(recovery.offsets_partition_for("my-app-group")).to eq(1_350_864_654 % partition_count)
    end

    it "produces different partitions for different consumer group ids" do
      partitions = %w[group-a group-b group-c group-d group-e].map do |g|
        recovery.offsets_partition_for(g)
      end

      expect(partitions.uniq.size).to be > 1
    end
  end

  describe ".coordinator_for" do
    it "returns a hash with partition, broker_id, and broker_host" do
      result = recovery.coordinator_for(consumer_group_id)
      expect(result).to have_key(:partition)
      expect(result).to have_key(:broker_id)
      expect(result).to have_key(:broker_host)
    end

    it "returns the correct partition for the group" do
      result = recovery.coordinator_for(consumer_group_id)
      expected_partition = recovery.offsets_partition_for(consumer_group_id)
      expect(result[:partition]).to eq(expected_partition)
    end

    it "returns a valid broker_id" do
      result = recovery.coordinator_for(consumer_group_id)
      expect(result[:broker_id]).to be_a(Integer)
    end

    it "returns a broker_host with host:port format" do
      result = recovery.coordinator_for(consumer_group_id)
      expect(result[:broker_host]).to match(/\A.+:\d+\z/)
    end
  end

  describe ".affected_groups" do
    context "when partition has consumer groups with committed offsets" do
      let(:group1) { SecureRandom.uuid }
      let(:group2) { SecureRandom.uuid }

      before do
        Karafka::Admin::ConsumerGroups.seek(group1, { topic => { 0 => 10 } })
        Karafka::Admin::ConsumerGroups.seek(group2, { topic => { 0 => 20 } })
      end

      it "discovers groups on their respective partition" do
        partition = recovery.offsets_partition_for(group1)
        result = recovery.affected_groups(partition)
        expect(result).to include(group1)
      end
    end

    context "when partition is out of range" do
      it "raises PartitionOutOfRangeError for negative partition" do
        expect do
          recovery.affected_groups(-1)
        end.to raise_error(
          described_class::Errors::PartitionOutOfRangeError,
          /out of range/
        )
      end

      it "raises PartitionOutOfRangeError for partition >= count" do
        partition_count = described_class.new.send(:offsets_partition_count)

        expect do
          recovery.affected_groups(partition_count)
        end.to raise_error(
          described_class::Errors::PartitionOutOfRangeError,
          /out of range/
        )
      end
    end

    it "returns a sorted array" do
      partition = recovery.offsets_partition_for(consumer_group_id)
      result = recovery.affected_groups(partition)
      expect(result).to be_an(Array)
      expect(result).to eq(result.sort)
    end
  end

  describe ".affected_partitions" do
    it "returns an array of integers" do
      metadata = Karafka::Admin.cluster_info
      broker = metadata.brokers.first
      broker_id = broker.is_a?(Hash) ? (broker[:broker_id] || broker[:node_id]) : broker.node_id

      result = recovery.affected_partitions(broker_id)
      expect(result).to be_an(Array)
      expect(result).to all be_a(Integer)
    end

    it "returns a sorted array" do
      metadata = Karafka::Admin.cluster_info
      broker = metadata.brokers.first
      broker_id = broker.is_a?(Hash) ? (broker[:broker_id] || broker[:node_id]) : broker.node_id

      result = recovery.affected_partitions(broker_id)
      expect(result).to eq(result.sort)
    end

    it "returns an empty array for a non-existent broker" do
      result = recovery.affected_partitions(99999)
      expect(result).to eq([])
    end
  end

  describe "#offsets_partition_count" do
    it "returns the partition count from cluster metadata" do
      count = described_class.new.send(:offsets_partition_count)
      expect(count).to be_a(Integer)
      expect(count).to be > 0
    end
  end

  describe "Karafka::Admin::Recovery alias" do
    it { expect(Karafka::Admin::Recovery).to eq(described_class) }
  end
end
