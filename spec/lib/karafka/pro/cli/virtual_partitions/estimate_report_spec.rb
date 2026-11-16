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
        expect { action.call }.to raise_error(Errno::ENOENT)
      end
    end

    context "when the file is not valid JSON" do
      before { File.write(path, "{not json") }

      it do
        expect { action.call }.to raise_error(JSON::ParserError)
      end
    end

    context "when format_version is not the current one" do
      before do
        estimator.analyze(messages, target_file: path)
        write_report(JSON.parse(File.read(path)).merge("format_version" => 2))
      end

      it "fails without printing the report" do
        expect { action.call }
          .to raise_error(
            Karafka::Errors::CommandValidationError,
            {
              format_version: "needs to match the format this Karafka version builds. " \
                "Generate the report again with this Karafka version"
            }.to_s
          )
          .and output("").to_stdout
      end
    end

    context "when the report has an invalid structure" do
      before do
        estimator.analyze(messages, target_file: path)
        write_report(JSON.parse(File.read(path)).merge("settings" => "x", "partitions" => [1, 2]))
      end

      it "fails with all the errors without printing the report" do
        expect { action.call }
          .to raise_error(
            Karafka::Errors::CommandValidationError,
            {
              settings: "needs to be an object",
              partitions: "needs to be an object with an object per partition"
            }.to_s
          )
          .and output("").to_stdout
      end
    end

    context "when the report is not a JSON object" do
      before { File.write(path, "[]") }

      it do
        expect { action.call }.to raise_error(
          Karafka::Errors::CommandValidationError,
          /format_version/
        )
      end
    end
  end
end
