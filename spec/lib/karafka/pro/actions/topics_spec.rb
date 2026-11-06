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
  subject(:action) { described_class.new(admin: admin) }

  let(:admin) { instance_double(Karafka::Pro::Actions::ReadOnlyAdmin) }
  let(:metadata) do
    Struct.new(:topics).new(
      [
        { topic_name: "orders", partition_count: 2 },
        { topic_name: "events", partition_count: 1 },
        { topic_name: "orders_dlq", partition_count: 1 }
      ]
    )
  end

  before { allow(admin).to receive(:cluster_info).and_return(metadata) }

  it "expect to return topics sorted by name" do
    expect(action.call.rows.map { |topic| topic[:topic] }).to eq(%w[events orders orders_dlq])
  end

  it "expect to filter topics with the pattern" do
    expect(action.call(pattern: "^orders").rows).to eq(
      [
        { topic: "orders", partition_count: 2 },
        { topic: "orders_dlq", partition_count: 1 }
      ]
    )
  end

  it "expect to paginate" do
    page = action.call(page: 2, per_page: 2)

    expect(page.rows.size).to eq(1)
    expect(page.has_more).to be(false)
  end
end
