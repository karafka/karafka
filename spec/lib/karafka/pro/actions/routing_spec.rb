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
  subject(:action) { described_class.new }

  let(:consumer) { Karafka::Pro::BaseConsumer }
  let(:topic) { Struct.new(:name, :consumer, :active?).new("orders", consumer, true) }
  let(:subscription_group) { Struct.new(:id, :topics).new("sg", [topic]) }
  let(:group) do
    Struct.new(:id, :group_type, :subscription_groups).new("cg", :consumer, [subscription_group])
  end

  before { allow(Karafka::App).to receive(:routes).and_return([group]) }

  it "expect to return routed topics with consumers source location" do
    row = action.call.first

    expect(row).to include(
      group_id: "cg",
      group_type: "consumer",
      subscription_group_id: "sg",
      topic: "orders",
      active: true,
      consumer: "Karafka::Pro::BaseConsumer"
    )
    expect(row[:source_location][:path]).to end_with("lib/karafka/pro/base_consumer.rb")
    expect(row[:source_location][:line]).to be_a(Integer)
  end

  context "when the consumer is anonymous" do
    let(:consumer) { Class.new }

    it { expect(action.call.first).to include(consumer: nil, source_location: nil) }
  end

  context "when there is no consumer" do
    let(:consumer) { nil }

    it { expect(action.call.first).to include(consumer: nil, source_location: nil) }
  end
end
