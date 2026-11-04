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
  subject(:partitioner) { described_class.new }

  let(:message) { build(:messages_message) }

  it "expect to return an increasing number per record" do
    expect(Array.new(4) { partitioner.call(message) }).to eq([1, 2, 3, 4])
  end

  context "when used with the default share virtual partitions reducer" do
    let(:topic) do
      build(:routing_share_topic).tap do |topic|
        topic.virtual_partitions(partitioner: partitioner, max_partitions: 3)
      end
    end

    let(:messages) { Array.new(7) { build(:messages_message) } }

    it "expect to spread records evenly one by one" do
      groups = topic.virtual_partitions.distributor.call(messages)

      expect(groups.values.map(&:size).sort).to eq([2, 2, 3])
      expect(groups.values.flatten).to match_array(messages)
    end
  end
end
