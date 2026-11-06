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
  subject(:estimator) { described_class.new(**settings) }

  let(:settings) { {} }
  let(:distributors) { Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Distributors }

  let(:distributor_config) do
    Struct.new(:partitioner, :reducer, :max_partitions).new(
      ->(message) { message.raw_key },
      ->(key) { key.to_s.sum % 5 },
      5
    )
  end

  def build_messages(keys, partition: 0, topic: "orders")
    keys.each_with_index.map do |key, offset|
      build(:messages_message, raw_key: key, offset: offset, partition: partition, topic: topic)
    end
  end

  describe "#initialize" do
    context "when settings are invalid" do
      let(:settings) { { concurrency: 0 } }

      it do
        expect { estimator }.to raise_error(Karafka::Errors::InvalidConfigurationError)
      end
    end

    context "when distribution is unknown" do
      let(:settings) { { distribution: :random } }

      it do
        expect { estimator }.to raise_error(Karafka::Errors::InvalidConfigurationError)
      end
    end
  end

  describe "#analyze" do
    subject(:result) { estimator.analyze(messages) }

    let(:messages) { build_messages(Array.new(200) { |i| "key-#{i % 20}" }) }

    it "uses the default concurrency and batch size" do
      expect(result[:settings]).to eq(
        concurrency: 5,
        distribution: :consistent,
        batch_size: 100,
        sample_size: 10_000,
        custom_partitioner: false,
        custom_reducer: false
      )
    end

    it { expect(result[:topic]).to eq("orders") }
    it { expect(result[:partitions].keys).to eq([0]) }
    it { expect(result[:partitions][0][:messages]).to eq(200) }
    it { expect(result[:partitions][0][:batches]).to eq(2) }
    it { expect(result[:partitions][0][:avg_unique_keys]).to eq(20.0) }
    it { expect(result[:summary][:messages]).to eq(200) }
    it { expect(result[:summary]).not_to have_key(:batches_details) }

    it "is deeply frozen" do
      expect(result).to be_frozen
      expect(result[:settings]).to be_frozen
      expect(result[:partitions][0]).to be_frozen
      expect(result[:partitions][0][:active_vps]).to be_frozen
    end

    it "does not include key values" do
      values = []
      collect = lambda do |object|
        case object
        when Hash then object.each_value { |value| collect.call(value) }
        when Array then object.each { |value| collect.call(value) }
        else values << object
        end
      end

      collect.call(estimator.class.new(details: true).analyze(messages))

      expect(values.grep(String)).to eq(["orders"])
    end

    context "when all messages have the same key" do
      let(:messages) { build_messages(Array.new(200) { "same" }) }

      it { expect(result[:summary][:avg_active_vps]).to eq(1.0) }
      it { expect(result[:summary][:single_vp_batches]).to eq(result[:summary][:batches]) }
      it { expect(result[:summary][:poor_batches]).to eq(2) }
      it { expect(result[:summary][:avg_speedup]).to eq(1.0) }
      it { expect(result[:summary][:verdict]).to eq(:not_recommended) }
    end

    context "when there are as many distinct keys as concurrency or more" do
      let(:settings) { { reducer: ->(key) { key.to_i % 5 } } }
      let(:messages) { build_messages(Array.new(200) { |i| (i % 10).to_s }) }

      it { expect(result[:summary][:avg_utilization]).to eq(100.0) }
      it { expect(result[:summary][:avg_parallelization]).to eq(100.0) }
      it { expect(result[:summary][:avg_load_imbalance]).to eq(0.0) }
      it { expect(result[:summary][:avg_speedup]).to eq(5.0) }
      it { expect(result[:summary][:score]).to eq(100) }
      it { expect(result[:summary][:verdict]).to eq(:recommended) }
      it { expect(result[:settings][:custom_reducer]).to be(true) }
    end

    context "when concurrency is 1" do
      let(:settings) { { concurrency: 1 } }

      it { expect(result[:summary][:active_vps]).to eq(min: 1, median: 1, max: 1) }
      it { expect(result[:summary][:collapsed_batches]).to eq(0) }
    end

    context "when partitioner raises" do
      let(:settings) { { partitioner: ->(_) { raise StandardError } } }

      it { expect { result }.not_to raise_error }
      it { expect(result[:summary][:collapsed_batches]).to eq(2) }
      it { expect(result[:summary][:single_vp_batches]).to eq(2) }
      it { expect(result[:settings][:custom_partitioner]).to be(true) }
    end

    context "when partitioner raises for one batch only" do
      let(:settings) do
        { partitioner: ->(message) { (message.offset == 150) ? raise(StandardError) : message.offset } }
      end

      it { expect(result[:summary][:collapsed_batches]).to eq(1) }
      it { expect(result[:summary][:active_vps]).to eq(min: 1, median: 5, max: 5) }
    end

    context "with details" do
      let(:settings) { { details: true } }

      it { expect(result[:partitions][0][:batches_details].size).to eq(2) }
      it { expect(result[:partitions][0][:batches_details].first[:first_offset]).to eq(0) }
      it { expect(result[:partitions][0][:batches_details].last[:last_offset]).to eq(199) }
    end

    context "when messages come from many partitions" do
      let(:messages) do
        build_messages(Array.new(150) { |i| i.to_s }, partition: 1) +
          build_messages(Array.new(50) { |i| i.to_s }, partition: 0)
      end

      it { expect(result[:partitions].keys).to eq([0, 1]) }
      it { expect(result[:partitions][0][:batches]).to eq(1) }
      it { expect(result[:partitions][1][:batches]).to eq(2) }
      it { expect(result[:summary][:batches]).to eq(3) }
      it { expect(result[:summary][:messages]).to eq(200) }
    end

    context "when there are no messages" do
      let(:messages) { [] }

      it { expect(result[:partitions]).to eq({}) }
      it { expect(result[:summary]).to include(messages: 0, batches: 0, score: nil, verdict: nil) }
    end

    context "when comparing with the real distributors" do
      let(:settings) { { details: true, batch_size: 200, distribution: distribution } }
      let(:messages) { build_messages(Array.new(200) { |i| "key-#{(i * 7) % 13}" }) }
      let(:details) { result[:partitions][0][:batches_details].first }

      context "when consistent" do
        let(:distribution) { :consistent }
        let(:expected) { distributors::Consistent.new(distributor_config).call(messages) }

        it { expect(details[:active_vps]).to eq(expected.size) }
        it { expect(details[:group_sizes]).to eq(expected.values.map(&:size).sort.reverse) }
      end

      context "when balanced" do
        let(:distribution) { :balanced }
        let(:expected) { distributors::Balanced.new(distributor_config).call(messages) }

        it { expect(details[:active_vps]).to eq(expected.size) }
        it { expect(details[:group_sizes]).to eq(expected.values.map(&:size).sort.reverse) }
      end
    end

    context "when custom reducer returns groups outside of concurrency" do
      let(:settings) { { reducer: ->(key) { key.to_s.sum } } }

      it { expect(result[:summary][:avg_active_vps]).to eq(20.0) }
      it { expect(result[:summary][:avg_utilization]).to eq(100.0) }
    end
  end

  describe "#call" do
    let(:topic) { "orders" }
    let(:iterator) { instance_double(Karafka::Pro::Iterator) }
    let(:messages) { build_messages(Array.new(30) { |i| i.to_s }, partition: 1) }
    let(:settings) { { sample_size: 50 } }

    before do
      allow(Karafka::Pro::Iterator).to receive(:new).and_return(iterator)
      allow(iterator).to receive(:each) { |&block| messages.each(&block) }
      allow(Karafka::Admin).to receive(:topic_info).and_return(partition_count: 2)
    end

    it "samples all partitions through the iterator" do
      estimator.call(topic)

      expect(Karafka::Pro::Iterator)
        .to have_received(:new).with({ topic => { 0 => -50, 1 => -50 } })
    end

    it "reports empty partitions" do
      result = estimator.call(topic)

      expect(result[:partitions][0]).to include(messages: 0, batches: 0, score: nil, verdict: nil)
      expect(result[:partitions][1][:messages]).to eq(30)
      expect(result[:topic]).to eq(topic)
    end

    context "when partitions are given" do
      it "samples only them" do
        estimator.call(topic, partitions: [1])

        expect(Karafka::Admin).not_to have_received(:topic_info)
        expect(Karafka::Pro::Iterator).to have_received(:new).with({ topic => { 1 => -50 } })
      end
    end
  end
end
