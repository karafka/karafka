# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
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

  # Regression: under multiplexing several subscription groups share the SAME consumer group
  # object but each runs its own listener thread and independently discovers the same topic.
  # ConsumerGroup#topic= appends unconditionally, so before the dedup guard the shared group
  # accumulated one duplicate Topic per subscription group (bounded by the multiplex factor),
  # polluting the routing tree.
  context "when the same topic is discovered from multiple subscription groups sharing a group" do
    let(:consumer_group) { build(:routing_consumer_group) }
    let(:pattern_topic_first) { build(:pattern_routing_topic, regexp: /.*/, group: consumer_group) }
    let(:pattern_topic_second) { build(:pattern_routing_topic, regexp: /.*/, group: consumer_group) }
    let(:sg_topics_first) { Karafka::Routing::Topics.new([pattern_topic_first]) }
    let(:sg_topics_second) { Karafka::Routing::Topics.new([pattern_topic_second]) }
    let(:discovered_first) { sg_topics_first.detect { |topic| topic.name == topic_name } }
    let(:discovered_second) { sg_topics_second.detect { |topic| topic.name == topic_name } }

    before do
      described_class.new.expand(sg_topics_first, topic_name)
      described_class.new.expand(sg_topics_second, topic_name)
    end

    it "expect the shared consumer group to register the discovered topic only once" do
      matching = consumer_group.topics.select { |topic| topic.name == topic_name }
      expect(matching.size).to eq(1)
    end

    it "expect each subscription group to see the discovered topic in its own topics" do
      expect(sg_topics_first.map(&:name)).to include(topic_name)
      expect(sg_topics_second.map(&:name)).to include(topic_name)
    end

    # Each subscription group must hold its own Topic instance: the Topic doubles as a per-SG
    # assignments key in AssignmentsTracker, so sharing one instance across multiplexed
    # subscription groups would collide their assignments.
    it "expect each subscription group to hold its own distinct topic instance" do
      expect(discovered_first).not_to equal(discovered_second)
    end

    it "expect each discovered topic to carry its own subscription group" do
      expect(discovered_first.subscription_group).to eq(pattern_topic_first.subscription_group)
      expect(discovered_second.subscription_group).to eq(pattern_topic_second.subscription_group)
    end
  end
end
