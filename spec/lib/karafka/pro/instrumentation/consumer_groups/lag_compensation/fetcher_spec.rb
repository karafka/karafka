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
  subject(:fetched) { fetcher.call(client, paused) }

  let(:fetcher) { described_class.new }
  let(:paused) { { "topic" => [0, 1] } }

  let(:committed_partitions) do
    [
      instance_double(Rdkafka::Consumer::Partition, partition: 0, offset: 5),
      instance_double(Rdkafka::Consumer::Partition, partition: 1, offset: nil)
    ]
  end

  let(:committed_tpl) do
    instance_double(
      Rdkafka::Consumer::TopicPartitionList,
      to_h: { "topic" => committed_partitions }
    )
  end

  let(:client) do
    instance_double(Karafka::Connection::Client, committed: committed_tpl)
  end

  before do
    allow(client).to receive(:query_watermark_offsets) do |_topic, partition|
      [1, 90 + partition]
    end
  end

  it "fetches end offsets per partition and committed offsets in one batched query" do
    expect(fetched).to eq(
      "topic" => {
        0 => { end_offset: 90, committed_offset: 5 },
        1 => { end_offset: 91, committed_offset: -1 }
      }
    )
  end

  it "queries committed offsets with a tpl covering all the paused partitions" do
    fetched

    expect(client).to have_received(:committed) do |tpl|
      expect(tpl.to_h.fetch("topic").map(&:partition)).to eq([0, 1])
    end
  end
end
