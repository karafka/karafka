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
  subject(:text) { described_class.new(report).call }

  let(:estimator_class) { Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator }
  let(:estimator) { estimator_class.new(concurrency: 5) }
  let(:messages) { build_messages(Array.new(200) { |i| "key-#{i % 20}" }) }
  let(:report) { JSON.parse(estimator.analyze(messages).to_json) }

  def build_messages(keys, partition: 0)
    keys.each_with_index.map do |key, offset|
      build(:messages_message, raw_key: key, offset: offset, partition: partition, topic: "orders")
    end
  end

  describe "#call" do
    context "with an estimator report" do
      it { expect(text).to be_a(String) }
      it { expect(text).to include("Virtual Partitions estimate for topic: orders") }
      it { expect(text).to include("concurrency: 5") }
      it { expect(text).to include("distribution: consistent") }
      it { expect(text).to include("verdict: #{estimator.analyze(messages)[:summary][:verdict]}") }
      it { expect(text).to include("The worker pool is shared with other partitions and topics.") }
      it { expect(text).not_to include("\e[") }
      it { expect(text).to include("Virtual Partitions should parallelize this data well.") }

      it "renders one row per partition" do
        rows = text.lines.select { |line| line.match?(/\A  \d+ /) }

        expect(rows.size).to eq(1)
        expect(rows.first).to start_with("  0  ")
      end
    end

    context "with 11 or more partitions" do
      let(:report) do
        report = JSON.parse(estimator.analyze(messages).to_json)
        stats = report["partitions"]["0"]
        report["partitions"] = %w[10 2 0 11].to_h { |partition| [partition, stats] }
        report
      end

      it "lists them in numeric order" do
        partitions = text.lines.filter_map { |line| line[/\A  (\d+) /, 1] }

        expect(partitions).to eq(%w[0 2 10 11])
      end
    end

    context "with an empty partition" do
      let(:report) do
        JSON.parse(
          {
            format_version: estimator_class::FORMAT_VERSION,
            topic_name: "orders",
            settings: { concurrency: 5 },
            partitions: { "0" => { messages: 0, batches: 0, score: nil, verdict: nil } },
            summary: { messages: 0, batches: 0, score: nil, verdict: nil }
          }.to_json
        )
      end

      it "renders - for the missing values" do
        row = text.lines.find { |line| line.start_with?("  0  ") }

        expect(row.split).to eq(%w[0 0 0 - - - - - - - -])
      end

      it { expect(text).to include("No messages to analyze.") }
      it { expect(text).not_to include("verdict:") }
    end

    context "when there are no messages" do
      let(:messages) { [] }

      it { expect(text).to include("No messages to analyze.") }
      it { expect(text).to include("Virtual Partitions estimate for topic: -") }
      it { expect(text).not_to include("Virtual Partitions should") }
    end

    context "when concurrency is 1" do
      let(:estimator) { estimator_class.new(concurrency: 1) }

      it { expect(text).to include("score: -/100") }
      it { expect(text).to include("verdict: not_recommended") }
      it { expect(text).to include("A concurrency below 2 runs each batch as one group") }
      it { expect(text).not_to include("Most batches use only a few keys") }
    end

    context "with unknown top level keys" do
      let(:report) do
        JSON.parse(estimator.analyze(messages).to_json).merge("future" => { "a" => 1 })
      end

      it { expect(text).to include("Virtual Partitions estimate for topic: orders") }
    end
  end
end
