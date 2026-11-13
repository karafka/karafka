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

      it "prints the text report" do
        report = JSON.parse(File.read(path))
        text = Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator::Reports::Text

        expect(printed).to eq("#{text.new(report).call}\n")
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

    context "when no path is given and the report file is configured" do
      subject(:action) { described_class.new }

      let(:estimator_config) { Karafka::App.config.consumer_groups.virtual_partitions.estimator }
      let(:original_report_file) { estimator_config.report_file }

      before do
        original_report_file
        estimator.analyze(messages, target_file: path)
        estimator_config.report_file = path
      end

      after { estimator_config.report_file = original_report_file }

      it { expect(printed).to include("Virtual Partitions estimate for topic: orders") }
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

    {
      "settings is not an object" => { "settings" => "x" },
      "partitions is not an object" => { "partitions" => [1, 2] },
      "a partition is null" => { "partitions" => { "0" => nil } },
      "summary is not an object" => { "summary" => 1 },
      "summary active_vps is not an object" => {
        "summary" => { "batches" => 1, "active_vps" => [1] }
      },
      "summary batches is an array" => { "summary" => { "batches" => [1] } },
      "summary batches is a boolean" => { "summary" => { "batches" => true } },
      "summary batches is a string" => { "summary" => { "batches" => "1" } }
    }.each do |description, overrides|
      context "when #{description}" do
        before do
          estimator.analyze(messages, target_file: path)
          write_report(JSON.parse(File.read(path)).merge(overrides))
        end

        it "fails without printing the report" do
          expect { action.call }
            .to raise_error(
              Karafka::Errors::CommandValidationError,
              "Estimate report is not valid: #{path}"
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
