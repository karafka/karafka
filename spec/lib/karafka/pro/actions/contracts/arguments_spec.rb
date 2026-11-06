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
  subject(:contract) { described_class.new(declarations) }

  let(:declarations) do
    {
      name: { type: :string, description: "Name", required: true },
      count: { type: :integer, description: "Count", required: false },
      pattern: { type: :regexp, description: "Pattern", required: false }
    }
  end

  it { expect(contract.call({ name: "x" })).to be_success }
  it { expect(contract.call({ name: "x", count: 1, pattern: "^a" })).to be_success }
  it { expect(contract.call({}).errors).to eq(name: "is required") }
  it { expect(contract.call({ name: "x", other: 1 }).errors).to eq(other: "is not an argument of this action") }
  it { expect(contract.call({ name: 1 }).errors).to eq(name: "has a wrong type or format") }
  it { expect(contract.call({ name: "x", count: "1" }).errors).to eq(count: "has a wrong type or format") }
  it { expect(contract.call({ name: "x", pattern: "(" }).errors).to eq(pattern: "has a wrong type or format") }
  it { expect(contract.call({ name: "x", pattern: 1 }).errors).to eq(pattern: "has a wrong type or format") }
end
