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
  subject(:contract) { described_class.new }

  it { expect(contract.call({})).to be_success }
  it { expect(contract.call({ page: 1, per_page: 1_000 })).to be_success }
  it { expect(contract.call({ page: 0 }).errors).to eq(page: "needs to be an integer of at least 1") }
  it { expect(contract.call({ page: "1" }).errors).to eq(page: "needs to be an integer of at least 1") }

  it "expect to reject a page size above the limit" do
    expect(contract.call({ per_page: 1_001 }).errors)
      .to eq(per_page: "needs to be an integer between 1 and 1000")
  end

  it { expect(contract.call({ per_page: 0 })).not_to be_success }
end
