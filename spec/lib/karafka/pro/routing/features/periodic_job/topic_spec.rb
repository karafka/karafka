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
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe "#periodic_job" do
    context "when we use periodic_job without any arguments" do
      it "expect to initialize with defaults" do
        expect(topic.periodic_job.active?).to be(false)
        expect(topic.periodic_job.interval).to eq(5_000)
      end
    end

    context "when used via the periodic alias without any arguments" do
      it "expect to initialize with defaults" do
        expect(topic.periodic.active?).to be(false)
        expect(topic.periodic_job.interval).to eq(5_000)
      end
    end

    context "when we use periodic_job with active status" do
      it "expect to use proper active status" do
        topic.periodic(true)
        expect(topic.periodic_job.active?).to be(true)
      end
    end

    context "when we use periodic_job multiple times with different values" do
      it "expect to use proper active status" do
        topic.periodic(true)
        topic.periodic(false)
        expect(topic.periodic_job.active?).to be(true)
        expect(topic.periodic_job.interval).to eq(5_000)
      end
    end

    context "when initialized only with interval" do
      it "expect to use proper active status and interval" do
        topic.periodic(interval: 2_500)
        expect(topic.periodic_job.active?).to be(true)
        expect(topic.periodic_job.interval).to eq(2_500)
      end
    end
  end

  describe "#periodic_job?" do
    context "when active" do
      before { topic.periodic(true) }

      it { expect(topic.periodic_job?).to be(true) }
    end

    context "when not active" do
      before { topic.periodic(false) }

      it { expect(topic.periodic_job?).to be(false) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:periodic_job]).to eq(topic.periodic_job.to_h) }
  end
end
