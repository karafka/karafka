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

  let(:config) do
    {
      concurrency: 5,
      batch_size: 100,
      sample_size: 10_000,
      distribution: :consistent,
      partitioner: nil,
      reducer: nil,
      details: false
    }
  end

  context "when config is valid" do
    it { expect(contract.call(config)).to be_success }
  end

  context "when partitioner and reducer are callables" do
    before do
      config[:partitioner] = ->(message) { message.raw_key }
      config[:reducer] = ->(key) { key.to_s.sum % 5 }
    end

    it { expect(contract.call(config)).to be_success }
  end

  context "when distribution is balanced" do
    before { config[:distribution] = :balanced }

    it { expect(contract.call(config)).to be_success }
  end

  %i[concurrency batch_size sample_size].each do |key|
    context "when #{key} is zero" do
      before { config[key] = 0 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context "when #{key} is not an integer" do
      before { config[key] = 1.5 }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context "when distribution is unknown" do
    before { config[:distribution] = :random }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when partitioner does not respond to call" do
    before { config[:partitioner] = "key" }

    it { expect(contract.call(config)).not_to be_success }

    it "explains the error" do
      expect(contract.call(config).errors)
        .to eq(partitioner: "needs to respond to #call when given")
    end
  end

  context "when reducer does not respond to call" do
    before { config[:reducer] = 1 }

    it { expect(contract.call(config)).not_to be_success }

    it "explains the error" do
      expect(contract.call(config).errors).to eq(reducer: "needs to respond to #call when given")
    end
  end

  context "when details is not a boolean" do
    before { config[:details] = "yes" }

    it { expect(contract.call(config)).not_to be_success }
  end
end
