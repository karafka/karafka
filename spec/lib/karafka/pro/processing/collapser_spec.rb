# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:collapser) { described_class.new }

  it "expect not to be collapsed by default" do
    expect(collapser.collapsed?).to be(false)
  end

  context "when no changes to until by default and reset" do
    before { collapser.refresh!(100) }

    it { expect(collapser.collapsed?).to be(false) }
  end

  context "when collapsed until previous offset" do
    before do
      collapser.collapse_until!(10)
      collapser.refresh!(100)
    end

    it { expect(collapser.collapsed?).to be(false) }
  end

  context "when collapsed until future offset" do
    before do
      collapser.collapse_until!(10_000)
      collapser.refresh!(100)
    end

    it { expect(collapser.collapsed?).to be(true) }
  end

  context "when collapsed until the offset" do
    before do
      collapser.collapse_until!(100)
      collapser.refresh!(100)
    end

    it { expect(collapser.collapsed?).to be(false) }
  end

  context "when collapsed but not refreshed" do
    before { collapser.collapse_until!(100) }

    it { expect(collapser.collapsed?).to be(false) }
  end

  context "when collapsed multiple times with earlier offsets" do
    before do
      collapser.collapse_until!(100)
      collapser.collapse_until!(10)
      collapser.collapse_until!(1)

      collapser.refresh!(99)
    end

    it { expect(collapser.collapsed?).to be(true) }
  end

  context "when collapsed multiple times with earlier offsets and refresh with younger" do
    before do
      collapser.collapse_until!(100)
      collapser.collapse_until!(10)
      collapser.collapse_until!(1)

      collapser.refresh!(101)
    end

    it { expect(collapser.collapsed?).to be(false) }
  end
end
