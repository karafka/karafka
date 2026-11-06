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
  let(:lags) do
    {
      "cg" => {
        "b" => { 0 => { offset: 5, lag: 1 } },
        "a" => { 1 => { offset: -1, lag: -1 }, 0 => { offset: 3, lag: 0 } }
      }
    }
  end
  let(:routes) do
    [
      Struct.new(:id, :topics).new("cg", [Struct.new(:name).new("a"), Struct.new(:name).new("b")]),
      Struct.new(:id, :topics).new("other", [Struct.new(:name).new("a")])
    ]
  end

  before do
    allow(Karafka::App.routes).to receive(:consumer_groups).and_return(routes)
    allow(admin).to receive(:read_lags_with_offsets).and_return(lags)
  end

  it "expect to return rows sorted by consumer group, topic and partition" do
    expect(action.call.rows).to eq(
      [
        { consumer_group_id: "cg", topic: "a", partition: 0, offset_committed: 3, lag_committed: 0 },
        { consumer_group_id: "cg", topic: "a", partition: 1, offset_committed: -1, lag_committed: -1 },
        { consumer_group_id: "cg", topic: "b", partition: 0, offset_committed: 5, lag_committed: 1 }
      ]
    )
  end

  it "expect to query all routed consumer groups by default" do
    action.call

    expect(admin).to have_received(:read_lags_with_offsets).with("cg" => %w[a b], "other" => %w[a])
  end

  it "expect to limit to a consumer group" do
    action.call(consumer_group_id: "other")

    expect(admin).to have_received(:read_lags_with_offsets).with("other" => %w[a])
  end

  it "expect to limit to a topic" do
    action.call(topic_name: "b")

    expect(admin).to have_received(:read_lags_with_offsets).with("cg" => %w[b])
  end

  it "expect to query a consumer group and topic that are not routed" do
    action.call(consumer_group_id: "external", topic_name: "x")

    expect(admin).to have_received(:read_lags_with_offsets).with("external" => %w[x])
  end

  it "expect not to query a consumer group without topics" do
    action.call(consumer_group_id: "external")

    expect(admin).to have_received(:read_lags_with_offsets).with({})
  end
end
