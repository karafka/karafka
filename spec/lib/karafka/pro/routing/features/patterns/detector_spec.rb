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
  subject(:detection) { described_class.new.expand(group_topics, topic_name) }

  let(:topic_name) { "my-new-topic" }

  context "when there are no patterns in the given subscription group topics set" do
    let(:group_topics) { build(:routing_subscription_group).topics }

    it "expect to do nothing" do
      expect { detection }.not_to(change { group_topics })
    end
  end

  context "when there are patterns in given subscription group topic set" do
    let(:group_topics) do
      topics = build(:routing_subscription_group).topics
      topics << build(:pattern_routing_topic)
      topics
    end

    context "when none matches" do
      it "expect not to change the group" do
        expect { detection }.not_to change(group_topics, :size)
      end

      it { expect { detection }.not_to raise_error }
    end

    context "when one matches" do
      let(:group_topics) do
        topics = build(:routing_subscription_group).topics
        topics << build(:pattern_routing_topic, regexp: /.*/)
        topics
      end

      context "when none matches" do
        let(:safe_detection) do
          detection
        rescue
        end

        it "expect not to change the group" do
          expect { safe_detection }.to change(group_topics, :size)
        end

        it { expect { detection }.not_to raise_error }
      end
    end
  end
end
