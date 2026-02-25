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
  subject(:max_epoch) { described_class.new }

  let(:grace_period) { 3_600 }

  describe "#initialize" do
    it "starts with a max value of -1" do
      expect(max_epoch.to_i).to eq(-1)
    end
  end

  describe "#update" do
    context "when new_max is greater than the current max" do
      it "updates the max value to new_max" do
        max_epoch.update(10)
        expect(max_epoch.to_i).to eq(10 - grace_period)
      end

      it "does not update the max value if new_max is not greater" do
        max_epoch.update(10)
        max_epoch.update(5)
        expect(max_epoch.to_i).to eq(10 - grace_period)
      end
    end

    context "when new_max is equal to the current max" do
      it "does not update the max value" do
        max_epoch.update(10)
        max_epoch.update(10)
        expect(max_epoch.to_i).to eq(10 - grace_period)
      end
    end
  end

  describe "#to_i" do
    context "when no updates have been made" do
      it "returns the initial value of -1" do
        expect(max_epoch.to_i).to eq(-1)
      end
    end

    context "when updates have been made" do
      it "returns the maximum value after updates" do
        max_epoch.update(100)
        expect(max_epoch.to_i).to eq(100 - grace_period)
        max_epoch.update(200)
        expect(max_epoch.to_i).to eq(200 - grace_period)
      end
    end
  end
end
