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
  subject(:action) { described_class.new(path) }

  let(:estimator_class) { Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator }
  let(:estimator) { estimator_class.new(concurrency: 5) }
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, "report.json") }
  let(:messages) { build_messages(Array.new(200) { |i| "key-#{i % 20}" }) }
  let(:printed) { capture_output { action.call } }

  after { FileUtils.rm_rf(dir) }

  def build_messages(keys, partition: 0)
    keys.each_with_index.map do |key, offset|
      build(:messages_message, raw_key: key, offset: offset, partition: partition, topic: "orders")
    end
  end

  def capture_output
    stdout = StringIO.new
    original = $stdout
    $stdout = stdout
    yield
    stdout.string
  ensure
    $stdout = original
  end

  def write_report(report)
    File.write(path, JSON.generate(report))
  end

  describe "#call" do
    context "with an estimator report" do
      before { estimator.analyze(messages, target_file: path) }

      it { expect(printed).to include("Virtual Partitions estimate for topic: orders") }
      it { expect(printed).to include("concurrency: 5") }
      it { expect(printed).to include("distribution: consistent") }
      it { expect(printed).to include("verdict: #{estimator.analyze(messages)[:summary][:verdict]}") }
      it { expect(printed).to include("The worker pool is shared with other partitions and topics.") }
      it { expect(printed).not_to include("\e[") }
      it { expect(printed).to include("Virtual Partitions should parallelize this data well.") }

      it "prints one row per partition" do
        rows = printed.lines.select { |line| line.match?(/\A  \d+ /) }

        expect(rows.size).to eq(1)
        expect(rows.first).to start_with("  0  ")
      end
    end

    context "with 11 or more partitions" do
      let(:messages) do
        Array.new(12) { |partition| build_messages(%w[a b c], partition: partition) }.flatten
      end

      before { estimator.analyze(messages, target_file: path) }

      it "lists them in numeric order" do
        partitions = printed.lines.filter_map { |line| line[/\A  (\d+) /, 1] }

        expect(partitions).to eq(Array.new(12) { |partition| partition.to_s })
      end
    end

    context "with an empty partition" do
      before do
        write_report(
          format_version: estimator_class::FORMAT_VERSION,
          topic_name: "orders",
          settings: { concurrency: 5 },
          partitions: { "0" => { messages: 0, batches: 0, score: nil, verdict: nil } },
          summary: { messages: 0, batches: 0, score: nil, verdict: nil }
        )
      end

      it "prints - for the missing values" do
        row = printed.lines.find { |line| line.start_with?("  0  ") }

        expect(row.split).to eq(%w[0 0 0 - - - - - - - -])
      end

      it { expect(printed).to include("No messages to analyze.") }
      it { expect(printed).not_to include("verdict:") }
    end

    context "when there are no messages" do
      let(:messages) { [] }

      before { estimator.analyze(messages, target_file: path) }

      it { expect(printed).to include("No messages to analyze.") }
      it { expect(printed).to include("Virtual Partitions estimate for topic: -") }
      it { expect(printed).not_to include("Virtual Partitions should") }
    end

    context "with unknown top level keys" do
      before do
        estimator.analyze(messages, target_file: path)
        write_report(JSON.parse(File.read(path)).merge("future" => { "a" => 1 }))
      end

      it { expect(printed).to include("Virtual Partitions estimate for topic: orders") }
    end

    context "when no path is given" do
      subject(:action) { described_class.new }

      before do
        estimator.analyze(messages, target_file: path)

        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with("report.json") { File.read(path) }
      end

      it "reads report.json from the current directory" do
        expect(printed).to include("Virtual Partitions estimate for topic: orders")
        expect(File).to have_received(:read).with("report.json")
      end
    end

    context "when the file does not exist" do
      it do
        expect { action.call }.to raise_error(
          Karafka::Errors::CommandValidationError,
          "Estimate report file not found: #{path}"
        )
      end
    end

    context "when the file is not valid JSON" do
      before { File.write(path, "{not json") }

      it do
        expect { action.call }.to raise_error(
          Karafka::Errors::CommandValidationError,
          "Estimate report is not valid JSON: #{path}"
        )
      end
    end

    {
      "missing" => nil,
      "2" => 2,
      "0" => 0,
      '"1"' => "1",
      "1.0" => 1.0
    }.each do |found, version|
      context "when format_version is #{found}" do
        before do
          estimator.analyze(messages, target_file: path)
          report = JSON.parse(File.read(path))
          version.nil? ? report.delete("format_version") : report["format_version"] = version
          write_report(report)
        end

        it "fails without printing the report" do
          expect { action.call }
            .to raise_error(
              Karafka::Errors::CommandValidationError,
              "Unsupported estimate report format_version: #{found} " \
              "(expected #{estimator_class::FORMAT_VERSION}). " \
              "Generate the report again with the Karafka version used to display it."
            )
            .and output("").to_stdout
        end
      end
    end

    context "when the report is not a JSON object" do
      before { File.write(path, "[]") }

      it do
        expect { action.call }.to raise_error(
          Karafka::Errors::CommandValidationError,
          /format_version: missing/
        )
      end
    end
  end
end
