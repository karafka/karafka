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
  subject(:expand) { described_class.new.call(topics) }

  context "when trying to expand on a non-existing topic" do
    let(:topics) { "it-topic-#{SecureRandom.uuid}" }

    it { expect { expand }.to raise_error(Karafka::Errors::TopicNotFoundError) }
  end

  context "when expanding on a full name" do
    let(:topics) { "it-#{SecureRandom.uuid}" }

    before { Karafka::Admin.create_topic(topics, 2, 1) }

    it { expect(expand).to eq({ topics => { 0 => 0, 1 => 0 } }) }
  end

  context "when expanding on full names" do
    let(:topics) { ["it-#{SecureRandom.uuid}", "it-#{SecureRandom.uuid}"] }

    before { topics.each { |topic| Karafka::Admin.create_topic(topic, 2, 1) } }

    it "expect to expand them all" do
      expect(expand).to eq(
        {
          topics[0] => { 0 => 0, 1 => 0 },
          topics[1] => { 0 => 0, 1 => 0 }
        }
      )
    end
  end

  context "when expanding on a full topic with given offset" do
    let(:topics) { { "it-#{SecureRandom.uuid}" => 100 } }

    before { Karafka::Admin.create_topic(topics.keys.first, 2, 1) }

    it { expect(expand).to eq({ topics.keys.first => { 0 => 100, 1 => 100 } }) }
  end

  # The negative offset lookup is left for integrations due to its nature

  context "when expanding on partitions with exact offsets" do
    let(:topics) { { "topic1" => { 0 => 5, 5 => 10 } } }

    it { expect(expand).to eq("topic1" => topics["topic1"]) }
  end

  context "when expanding on a full topic with a time" do
    let(:time) { Time.now }
    let(:topics) { { "it-#{SecureRandom.uuid}" => time } }

    before { Karafka::Admin.create_topic(topics.keys.first, 2, 1) }

    it { expect(expand).to eq({ topics.keys.first => { 0 => time, 1 => time } }) }
  end

  context "when expanding on partitions with times" do
    let(:time1) { Time.now }
    let(:time2) { Time.now + 60 }
    let(:topics) { { "topic1" => { 0 => time1, 5 => time2 } } }

    it { expect(expand).to eq("topic1" => topics["topic1"]) }
  end
end
