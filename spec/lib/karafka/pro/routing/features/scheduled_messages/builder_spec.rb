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
  subject(:builder) do
    Karafka::Routing::Builder.new.tap do |builder|
      builder.singleton_class.prepend described_class
    end
  end

  let(:topic) { builder.first.topics.first }

  describe "#scheduled_messages" do
    context "when defining scheduled messages without any extra settings" do
      before { builder.scheduled_messages("test_name") }

      it { expect(topic.consumer).to eq(Karafka::Pro::ScheduledMessages::Consumer) }
      it { expect(topic.scheduled_messages?).to be(true) }
    end

    context "when defining scheduled messages with extra settings" do
      before do
        builder.scheduled_messages("test_name") do
          max_messages 5
        end
      end

      it { expect(topic.consumer).to eq(Karafka::Pro::ScheduledMessages::Consumer) }
      it { expect(topic.scheduled_messages?).to be(true) }
      it { expect(topic.max_messages).to eq(5) }
      it { expect(builder.first.topics.size).to eq(2) }
      it { expect(builder.size).to eq(1) }
    end

    context "when defining multiple scheduled topics" do
      before do
        builder.scheduled_messages("test_name1") do
          max_messages 5
        end

        builder.scheduled_messages("test_name2")
      end

      it { expect(builder.first.topics.size).to eq(4) }
      it { expect(builder.size).to eq(1) }
    end
  end
end
