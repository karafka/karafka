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
  subject(:distributor) { described_class.new(config) }

  let(:config) do
    Karafka::Pro::Routing::Features::ShareGroups::VirtualPartitions::Config.new(
      active: true,
      partitioner: :round_robin,
      max_partitions: 3,
      reducer: nil,
      distribution: :consistent
    )
  end

  let(:messages) { Array.new(7) { build(:messages_message) } }

  it "expect to spread records evenly one by one" do
    result = distributor.call(messages)

    expect(result.keys).to eq([0, 1, 2])
    expect(result[0]).to eq([messages[0], messages[3], messages[6]])
    expect(result[1]).to eq([messages[1], messages[4]])
    expect(result[2]).to eq([messages[2], messages[5]])
  end

  context "when there are fewer records than virtual partitions" do
    let(:messages) { [build(:messages_message)] }

    it { expect(distributor.call(messages)).to eq(0 => messages) }
  end
end
