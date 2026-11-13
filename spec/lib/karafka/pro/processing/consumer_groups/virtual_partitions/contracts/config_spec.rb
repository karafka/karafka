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
      consumer_groups: {
        virtual_partitions: {
          estimator: {
            sample_size: 10_000,
            distribution: :consistent,
            report_file: "report.json",
            recommended_score: 70,
            maybe_score: 40,
            score_weights: {
              utilization: 40,
              parallelization: 30,
              balance: 20,
              stability: 10
            }
          }
        }
      }
    }
  end

  let(:estimator) { config[:consumer_groups][:virtual_partitions][:estimator] }
  let(:errors) { contract.call(config).errors }

  context "when config is valid" do
    it { expect(contract.call(config)).to be_success }
  end

  context "when distribution is balanced" do
    before { estimator[:distribution] = :balanced }

    it { expect(contract.call(config)).to be_success }
  end

  {
    sample_size: [0, "1", nil],
    distribution: [:random, "consistent"],
    report_file: ["", nil, 1],
    recommended_score: [-1, 101, 70.0],
    maybe_score: [-1, 101, "40"]
  }.each do |key, values|
    values.each do |value|
      context "when #{key} is #{value.inspect}" do
        before { estimator[key] = value }

        it { expect(contract.call(config)).not_to be_success }
      end
    end
  end

  %i[utilization parallelization balance stability].each do |weight|
    context "when the #{weight} weight is negative" do
      before { estimator[:score_weights][weight] = -1 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context "when the #{weight} weight is not an integer" do
      before { estimator[:score_weights][weight] = 10.0 }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context "when maybe_score is above recommended_score" do
    before { estimator[:maybe_score] = 71 }

    it { expect(contract.call(config)).not_to be_success }

    it do
      expect(errors[:"consumer_groups.virtual_partitions.estimator.maybe_score"])
        .to eq("needs to be equal or lower than recommended_score")
    end
  end

  context "when maybe_score is equal to recommended_score" do
    before { estimator[:maybe_score] = 70 }

    it { expect(contract.call(config)).to be_success }
  end

  context "when score weights do not sum up to 100" do
    before { estimator[:score_weights][:stability] = 11 }

    it { expect(contract.call(config)).not_to be_success }

    it do
      expect(errors[:"consumer_groups.virtual_partitions.estimator.score_weights"])
        .to eq("needs to sum up to 100")
    end
  end
end
