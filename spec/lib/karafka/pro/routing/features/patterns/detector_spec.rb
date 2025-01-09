# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:detection) { described_class.new.expand(group_topics, topic_name) }

  let(:topic_name) { 'my-new-topic' }

  context 'when there are no patterns in the given subscription group topics set' do
    let(:group_topics) { build(:routing_subscription_group).topics }

    it 'expect to do nothing' do
      expect { detection }.not_to(change { group_topics })
    end
  end

  context 'when there are patterns in given subscription group topic set' do
    let(:group_topics) do
      topics = build(:routing_subscription_group).topics
      topics << build(:pattern_routing_topic)
      topics
    end

    context 'when none matches' do
      it 'expect not to change the group' do
        expect { detection }.not_to change(group_topics, :size)
      end

      it { expect { detection }.not_to raise_error }
    end

    context 'when one matches' do
      let(:group_topics) do
        topics = build(:routing_subscription_group).topics
        topics << build(:pattern_routing_topic, regexp: /.*/)
        topics
      end

      context 'when none matches' do
        let(:safe_detection) do
          detection
        rescue StandardError
        end

        it 'expect not to change the group' do
          expect { safe_detection }.to change(group_topics, :size)
        end

        it { expect { detection }.not_to raise_error }
      end
    end
  end
end
