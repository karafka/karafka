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
  subject(:topic) { build(:routing_topic) }

  describe "#throttling" do
    context "when we use throttling without any arguments" do
      it "expect to initialize with defaults" do
        expect(topic.throttling.active?).to be(false)
      end
    end

    context "when we use throttling with good limit value" do
      it "expect to use proper active status" do
        topic.throttling(limit: 100)
        expect(topic.throttling.active?).to be(true)
      end
    end

    context "when we use throttling multiple times with different values" do
      it "expect to use proper active status" do
        topic.throttling(limit: 100)
        topic.throttle(limit: Float::INFINITY)
        expect(topic.throttling.active?).to be(true)
      end
    end
  end

  describe "#throttling?" do
    context "when active" do
      before { topic.throttling(limit: 100) }

      it { expect(topic.throttling?).to be(true) }
    end

    context "when not active" do
      before { topic.throttling }

      it { expect(topic.throttling?).to be(false) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:throttling]).to eq(topic.throttling.to_h) }
  end
end
