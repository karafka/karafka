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
  # We test this module by creating a test class that mimics how OSS DefaultsInjector works
  # with the Pro module prepended on its singleton class
  let(:test_injector) do
    mod = described_class

    Class.new do
      class << self
        def consumer(kafka_config)
          kafka_config
        end

        def managed_keys
          Set.new
        end
      end

      singleton_class.prepend(mod)
    end
  end

  describe "#managed_keys" do
    it "returns an empty set since Pro handles these keys" do
      keys = test_injector.managed_keys
      expect(keys).to be_a(Set)
      expect(keys).to be_empty
    end
  end

  describe "#consumer" do
    context "when statistics.unassigned.include is not set" do
      let(:kafka_config) { {} }

      it "sets it to false" do
        test_injector.consumer(kafka_config)
        expect(kafka_config[:"statistics.unassigned.include"]).to be(false)
      end
    end

    context "when statistics.unassigned.include is already set" do
      let(:kafka_config) { { "statistics.unassigned.include": true } }

      it "does not overwrite it" do
        test_injector.consumer(kafka_config)
        expect(kafka_config[:"statistics.unassigned.include"]).to be(true)
      end
    end

    it "calls super" do
      kafka_config = {}
      result = test_injector.consumer(kafka_config)
      expect(result).to eq(kafka_config)
    end
  end
end
