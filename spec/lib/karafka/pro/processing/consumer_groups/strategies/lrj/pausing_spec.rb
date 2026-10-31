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
  let(:strategies) { Karafka::Pro::Processing::ConsumerGroups::StrategySelector.new.strategies }
  let(:lrj_strategies) { strategies.select { |s| s::FEATURES.include?(:long_running_job) } }

  it "expect every LRJ strategy to pause with it" do
    lrj_strategies.each do |strategy|
      expect(strategy.instance_method(:pause).owner).to eq(described_class)
    end
  end

  it "expect no other strategy to include it" do
    (strategies - lrj_strategies).each do |strategy|
      expect(strategy.include?(described_class)).to be(false)
    end
  end
end
