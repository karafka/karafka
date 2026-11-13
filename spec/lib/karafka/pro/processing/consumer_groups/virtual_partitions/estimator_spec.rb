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
  subject(:estimator) { described_class.new(concurrency: 5, **settings) }

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
      subject(:estimator) { described_class.new(concurrency: 0) }

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

    it "uses the app concurrency and max messages by default" do
      expect(described_class.new.analyze(messages)[:settings]).to eq(
        concurrency: Karafka::App.config.concurrency,
        distribution: :consistent,
        batch_size: Karafka::App.config.max_messages,
        sample_size: 10_000,
        custom_partitioner: false,
        custom_reducer: false
      )
    end

    context "with the balanced distribution" do
      let(:settings) { { distribution: :balanced } }

      it { expect(result[:settings][:distribution]).to eq(:balanced) }
    end

    context "when the estimator defaults are configured" do
      let(:estimator_config) { Karafka::App.config.consumer_groups.virtual_partitions.estimator }
      let(:original_config) { estimator_config.to_h }

      before do
        original_config
        estimator_config.distribution = :balanced
        estimator_config.sample_size = 20
      end

      after do
        estimator_config.distribution = original_config[:distribution]
        estimator_config.sample_size = original_config[:sample_size]
      end

      it "uses them" do
        expect(described_class.new.analyze(messages)[:settings]).to include(
          distribution: :balanced,
          sample_size: 20
        )
      end
    end

    it { expect(result.keys.first).to eq(:format_version) }
    it { expect(result[:format_version]).to eq(described_class::FORMAT_VERSION) }
    it { expect(result[:topic_name]).to eq("orders") }
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

    it "survives JSON serialization" do
      parsed = JSON.parse(result.to_json)

      expect(parsed["format_version"]).to eq(described_class::FORMAT_VERSION)
      expect(parsed["topic_name"]).to eq("orders")
      expect(parsed["settings"]["distribution"]).to eq("consistent")
      expect(parsed["partitions"]["0"]["messages"]).to eq(200)
      expect(parsed["partitions"]["0"]["verdict"]).to eq(result[:partitions][0][:verdict].to_s)
      expect(parsed["summary"]["score"]).to eq(result[:summary][:score])
      expect(parsed["summary"]["active_vps"]).to eq(result[:summary][:active_vps].transform_keys(&:to_s))
    end

    it "does not freeze the topic of the messages" do
      topic_name = +"orders"

      estimator.analyze(build_messages(%w[a b], topic: topic_name))

      expect(topic_name).not_to be_frozen
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

      collect.call(described_class.new(details: true).analyze(messages))

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
      it { expect(result[:summary]).to include(score: nil, verdict: :not_recommended) }
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
      it { expect(result[:summary][:active_vps]).to eq(min: 1, median: 3.0, max: 5) }
    end

    context "when partitioner raises for one of uneven batches" do
      let(:settings) do
        {
          partitioner: lambda do |message|
            raise(StandardError) if message.offset == 150

            (message.offset % 10 < 6) ? 0 : 1
          end
        }
      end

      it "leaves the collapsed batch out of the load imbalance" do
        expect(result[:summary]).to include(collapsed_batches: 1, avg_load_imbalance: 20.0)
      end
    end

    context "when partitioner raises with concurrency of 1" do
      let(:settings) { { concurrency: 1, partitioner: ->(_) { raise StandardError } } }

      it { expect(result[:summary][:collapsed_batches]).to eq(0) }
    end

    context "when the partitioner is not deterministic" do
      let(:settings) { { batch_size: 10, partitioner: ->(_) { calls << calls.size } } }
      let(:messages) { build_messages(Array.new(10) { "same" }) }
      let(:calls) { [] }

      it "runs it once per message" do
        result

        expect(calls.size).to eq(10)
      end
    end

    context "with a partly spread batch with null keys" do
      let(:settings) { { concurrency: 4, batch_size: 8, reducer: ->(key) { key.to_i % 4 } } }
      let(:messages) { build_messages(["0", "0", "0", "0", "1", "1", nil, nil]) }

      it "computes the exact metrics" do
        expect(result[:summary]).to include(
          avg_unique_keys: 3.0,
          avg_null_keys: 2.0,
          avg_active_vps: 2.0,
          avg_utilization: 50.0,
          avg_load_imbalance: 50.0,
          avg_parallelization: 33.3,
          avg_speedup: 1.3,
          poor_batches: 0,
          single_vp_batches: 0,
          score: 50,
          verdict: :maybe
        )
      end
    end

    context "with a load imbalance above 100%" do
      let(:settings) { { concurrency: 4, batch_size: 10, reducer: ->(key) { key.to_i % 4 } } }
      let(:messages) { build_messages(Array.new(7) { "0" } + %w[1 2 3]) }

      it "does not let the imbalance lower the score below its weight" do
        expect(result[:summary]).to include(
          avg_utilization: 100.0,
          avg_load_imbalance: 103.9,
          avg_parallelization: 35.7,
          score: 61,
          verdict: :maybe
        )
      end
    end

    context "with a slightly uneven batch" do
      let(:settings) { { concurrency: 4, batch_size: 9, reducer: ->(key) { key.to_i % 4 } } }
      let(:messages) { build_messages(%w[0 0 0 1 1 2 2 3 3]) }

      it "computes the exact metrics" do
        expect(result[:summary]).to include(
          avg_load_imbalance: 19.2,
          avg_parallelization: 75.0,
          score: 89,
          verdict: :recommended
        )
      end
    end

    context "with details" do
      let(:settings) { { details: true } }

      it { expect(result[:partitions][0][:batches_details].size).to eq(2) }
      it { expect(result[:partitions][0][:batches_details].first[:first_offset]).to eq(0) }
      it { expect(result[:partitions][0][:batches_details].last[:last_offset]).to eq(199) }

      it "survives JSON serialization" do
        details = JSON.parse(result.to_json)["partitions"]["0"]["batches_details"]

        expect(details.size).to eq(2)
        expect(details.first["first_offset"]).to eq(0)
        expect(details.first["group_sizes"]).to eq(result[:partitions][0][:batches_details].first[:group_sizes])
      end

      context "when messages are not in offset order" do
        let(:messages) { build_messages(Array.new(200) { |i| "key-#{i % 20}" }).reverse }

        it "batches them in offset order" do
          details = result[:partitions][0][:batches_details]

          expect(details.map { |batch| [batch[:first_offset], batch[:last_offset]] })
            .to eq([[0, 99], [100, 199]])
        end
      end
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

    context "with target_file" do
      subject(:result) { estimator.analyze(messages, target_file: target_file) }

      let(:dir) { Dir.mktmpdir }
      let(:target_file) { File.join(dir, "report.json") }

      after { FileUtils.rm_rf(dir) }

      it "writes the JSON report and returns the frozen result" do
        expect(result).to be_frozen
        expect(JSON.parse(File.read(target_file))).to eq(JSON.parse(result.to_json))
        expect(JSON.parse(File.read(target_file))["format_version"])
          .to eq(described_class::FORMAT_VERSION)
      end

      it "pretty prints the JSON report" do
        result

        expect(File.read(target_file)).to include("{\n  \"format_version\": 1,\n")
      end

      it "returns the same data as without target_file" do
        expect(result).to eq(estimator.analyze(messages))
      end

      context "when given as a Pathname" do
        let(:target_file) { Pathname.new(dir).join("report.json") }

        it "writes the JSON report there" do
          expected = JSON.parse(result.to_json)

          expect(JSON.parse(File.read(target_file))).to eq(expected)
        end
      end

      context "when the file already exists" do
        before { File.write(target_file, "old content" * 1_000) }

        it "writes the JSON report there" do
          expected = JSON.parse(result.to_json)

          expect(JSON.parse(File.read(target_file))).to eq(expected)
        end
      end

      context "when the directory does not exist" do
        let(:target_file) { File.join(dir, "missing", "report.json") }

        it { expect { result }.to raise_error(Errno::ENOENT) }
      end
    end

    context "when target_file is not given" do
      it "writes nothing" do
        allow(File).to receive(:write)

        result

        expect(File).not_to have_received(:write)
      end
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
    let(:topic_name) { "orders" }
    let(:iterator) { instance_double(Karafka::Pro::Iterator) }
    let(:messages) { build_messages(Array.new(30) { |i| i.to_s }, partition: 1) }
    let(:settings) { { sample_size: 50 } }

    before do
      allow(Karafka::Pro::Iterator).to receive(:new).and_return(iterator)
      allow(iterator).to receive(:each) { |&block| messages.each(&block) }
      allow(Karafka::Admin).to receive(:topic_info).and_return(partition_count: 2)
    end

    it "does not freeze the given topic name" do
      topic_name = +"orders"

      estimator.call(topic_name)

      expect(topic_name).not_to be_frozen
    end

    it "samples all partitions through the iterator" do
      estimator.call(topic_name)

      expect(Karafka::Pro::Iterator)
        .to have_received(:new).with({ topic_name => { 0 => -50, 1 => -50 } })
    end

    it "reports empty partitions" do
      result = estimator.call(topic_name)

      expect(result[:partitions][0]).to include(messages: 0, batches: 0, score: nil, verdict: nil)
      expect(result[:partitions][1][:messages]).to eq(30)
      expect(result[:topic_name]).to eq(topic_name)
    end

    context "with target_file" do
      let(:dir) { Dir.mktmpdir }
      let(:target_file) { File.join(dir, "report.json") }

      after { FileUtils.rm_rf(dir) }

      it "writes the JSON report and returns the frozen result" do
        result = estimator.call(topic_name, target_file: target_file)

        expect(result).to be_frozen
        expect(JSON.parse(File.read(target_file))).to eq(JSON.parse(result.to_json))
      end
    end

    context "when partitions are interleaved" do
      let(:settings) { { sample_size: 50, batch_size: 10 } }
      let(:messages) do
        build_messages(Array.new(25) { |i| "a-#{i % 7}" }, partition: 0)
          .zip(build_messages(Array.new(25) { |i| "b-#{i % 3}" }, partition: 1))
          .flatten
      end

      it "estimates each partition as #analyze does" do
        expect(estimator.call(topic_name)[:partitions])
          .to eq(estimator.analyze(messages)[:partitions])
      end
    end

    context "when iterating" do
      let(:calls) { [] }
      let(:settings) { { sample_size: 50, batch_size: 10, partitioner: ->(_) { calls << 1 } } }
      let(:calls_seen) { [] }

      before do
        allow(iterator).to receive(:each) do |&block|
          messages.each do |message|
            calls_seen << calls.size
            block.call(message)
          end
        end
      end

      it "estimates each full batch without waiting for the rest" do
        estimator.call(topic_name)

        expect(calls_seen.values_at(9, 10, 20)).to eq([0, 10, 20])
      end
    end

    context "when partitions are given" do
      it "samples only them" do
        estimator.call(topic_name, partitions: [1])

        expect(Karafka::Admin).not_to have_received(:topic_info)
        expect(Karafka::Pro::Iterator).to have_received(:new).with({ topic_name => { 1 => -50 } })
      end
    end
  end
end
