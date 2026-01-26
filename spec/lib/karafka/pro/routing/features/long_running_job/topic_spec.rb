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

  describe "#long_running_job" do
    context "when we use long_running_job without any arguments" do
      it "expect to initialize with defaults" do
        expect(topic.long_running_job.active?).to be(false)
      end
    end

    context "when we use long_running_job with active status" do
      it "expect to use proper active status" do
        topic.long_running_job(true)
        expect(topic.long_running_job.active?).to be(true)
      end
    end

    context "when we use long_running_job multiple times with different values" do
      it "expect to use proper active status" do
        topic.long_running_job(true)
        topic.long_running_job(false)
        expect(topic.long_running_job.active?).to be(true)
      end
    end
  end

  describe "#long_running_job?" do
    context "when active" do
      before { topic.long_running_job(true) }

      it { expect(topic.long_running_job?).to be(true) }
    end

    context "when not active" do
      before { topic.long_running_job(false) }

      it { expect(topic.long_running_job?).to be(false) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:long_running_job]).to eq(topic.long_running_job.to_h) }
  end
end
