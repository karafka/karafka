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
  subject(:day) { described_class.new }

  describe "#created_at" do
    it "returns the UTC timestamp when the day object was created" do
      expect(day.created_at).to be_within(1).of(Time.now.to_i)
    end
  end

  describe "#ends_at" do
    it "returns the UTC timestamp of the last second of the day" do
      time = Time.at(day.created_at)
      expected_end_time = Time.utc(time.year, time.month, time.day).to_i + 86_399
      expect(day.ends_at).to eq(expected_end_time)
    end
  end

  describe "#ended?" do
    context "when the current time is before the end of the day" do
      it "returns false" do
        allow(Time).to receive(:now).and_return(Time.at(day.ends_at - 1))
        expect(day.ended?).to be(false)
      end
    end

    context "when the current time is after the end of the day" do
      it "returns true" do
        allow(Time).to receive(:now).and_return(Time.at(day.ends_at + 1))
        expect(day.ended?).to be(true)
      end
    end
  end
end
