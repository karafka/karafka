# frozen_string_literal: true

RSpec.describe_current do
  subject(:detection) { described_class.new.expand(group_topics, topic_name) }

  let(:topic_name) { 'my-new-topic' }

  context 'when there are no patterns in the given subscription group topics set' do
    let(:group_topics) { build(:routing_subscription_group).topics }

    it 'expect to do nothing' do
      expect { detection }.not_to change { group_topics }
    end
  end

  context 'when there are patterns in given subscription group topic set' do
    let(:group_topics) do
      topics = build(:routing_subscription_group).topics
      topics << build(:pattern_routing_topic)
      topics
    end

    context 'when none matches' do
      let(:expected_errror) do
        ::Karafka::Pro::Routing::Features::Patterns::Errors::PatternNotMatchedError
      end

      let(:safe_detection) do
        begin
          detection
        rescue StandardError
        end
      end

      it 'expect not to change the group' do
        expect { safe_detection }.not_to change { group_topics }
      end

      it { expect { detection }.to raise_error(expected_errror) }
    end

    context 'when one matches' do
      pending
    end
  end
end
