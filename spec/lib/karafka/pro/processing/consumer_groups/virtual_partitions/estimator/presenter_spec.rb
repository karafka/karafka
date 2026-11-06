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
  subject(:report) { described_class.new(result).to_s }

  let(:estimator) { Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator.new(concurrency: 5) }

  let(:messages) do
    Array.new(200) do |i|
      build(:messages_message, raw_key: "key-#{i % 20}", offset: i, topic: "orders")
    end
  end

  let(:result) { estimator.analyze(messages) }

  it { expect(report).to be_a(String) }
  it { expect(report).not_to include("\e[") }
  it { expect(report).to include("Virtual Partitions estimate for topic: orders") }
  it { expect(report).to include("concurrency: 5") }
  it { expect(report).to include("verdict: #{result[:summary][:verdict]}") }
  it { expect(report).to include("GVL") }
  it { expect(report.lines.grep(/\A  0 /).size).to eq(1) }

  context "when there are no messages" do
    let(:messages) { [] }

    it { expect(report).to include("No messages to analyze.") }
    it { expect(report).not_to include("\e[") }
  end

  context "when a partition is empty" do
    let(:result) do
      estimator.analyze(messages).merge(partitions: { 0 => { messages: 0, batches: 0 } })
    end

    it { expect(report.lines.grep(/\A  0 +0 +0 +- /).size).to eq(1) }
  end
end
