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
  let(:client) { instance_double(Karafka::Connection::Client) }

  before do
    allow(client).to receive(:query_watermark_offsets) do |_topic, partition|
      [1, 90 + partition]
    end
  end

  it "fetches end offsets of all the requested partitions" do
    expect(fetched).to eq("topic" => { 0 => 90, 1 => 91 })
  end

  it "does not query anything else than the watermarks" do
    fetched

    expect(client).to have_received(:query_watermark_offsets).twice
  end
end
