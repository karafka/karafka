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

  describe "#delaying" do
    context "when we use delaying without any arguments" do
      it "expect to initialize with defaults" do
        expect(topic.delaying.active?).to be(false)
      end
    end

    context "when we use delaying with a delay" do
      it "expect to use proper active status" do
        topic.delaying(1)
        expect(topic.delaying.active?).to be(true)
      end
    end

    context "when we use delaying multiple times with different values" do
      before do
        topic.delaying(1)
        topic.delay_by(2)
      end

      it "expect to use proper active status" do
        expect(topic.delaying.active?).to be(true)
      end

      it "expect not to add second expire" do
        expect(topic.filter.factories.size).to eq(1)
      end
    end
  end

  describe "#delaying?" do
    context "when active" do
      before { topic.delaying(1) }

      it { expect(topic.delaying?).to be(true) }
    end

    context "when not active" do
      before { topic.delaying }

      it { expect(topic.delaying?).to be(false) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:delaying]).to eq(topic.delaying.to_h) }
  end
end
