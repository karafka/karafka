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
  # Minimal host exposing a settable `#action`, the way filters and the applier do
  let(:host_class) do
    Class.new do
      include Karafka::Pro::Processing::ConsumerGroups::Filters::Actions

      attr_accessor :action

      def initialize(action)
        @action = action
      end
    end
  end

  describe "ALL" do
    it "lists every supported action" do
      expect(described_class::ALL).to eq(%i[skip pause seek])
    end

    it "is frozen" do
      expect(described_class::ALL).to be_frozen
    end
  end

  describe "predicates" do
    it "resolves #skip? only for :skip" do
      expect(host_class.new(:skip).skip?).to be(true)
      expect(host_class.new(:pause).skip?).to be(false)
      expect(host_class.new(:seek).skip?).to be(false)
    end

    it "resolves #pause? only for :pause" do
      expect(host_class.new(:pause).pause?).to be(true)
      expect(host_class.new(:skip).pause?).to be(false)
      expect(host_class.new(:seek).pause?).to be(false)
    end

    it "resolves #seek? only for :seek" do
      expect(host_class.new(:seek).seek?).to be(true)
      expect(host_class.new(:skip).seek?).to be(false)
      expect(host_class.new(:pause).seek?).to be(false)
    end
  end
end
