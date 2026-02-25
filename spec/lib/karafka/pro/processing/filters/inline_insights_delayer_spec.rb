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
  subject(:delayer) { described_class.new(topic, partition) }

  let(:topic) { build(:routing_topic) }
  let(:partition) { rand(100) }
  let(:message) { build(:messages_message, topic: topic.name, partition: partition) }

  context "when there are no messages" do
    before { delayer.apply!([]) }

    it { expect(delayer.applied?).to be(false) }
    it { expect(delayer.timeout).to be_nil }
    it { expect(delayer.action).to eq(:skip) }
  end

  context "when insights exist" do
    before do
      allow(Karafka::Processing::InlineInsights::Tracker)
        .to receive(:find)
        .with(topic, partition)
        .and_return(rand => rand)

      delayer.apply!([message])
    end

    it { expect(delayer.applied?).to be(false) }
    it { expect(delayer.timeout).to be_nil }
    it { expect(delayer.action).to eq(:skip) }
  end

  context "when insights do not exist" do
    before { delayer.apply!([message]) }

    it { expect(delayer.applied?).to be(true) }
    it { expect(delayer.timeout).to eq(5_000) }
    it { expect(delayer.action).to eq(:pause) }
  end
end
