# frozen_string_literal: true

RSpec.describe_current do
  subject(:partitioner) { described_class.new(subscription_group) }

  let(:subscription_group) { build(:routing_subscription_group) }

  describe '#call' do
    let(:topic) { 'topic-name' }
    let(:messages) { [build(:messages_message)] }

    it 'expect to yield with 0 and input messages' do
      expect { |block| partitioner.call(topic, messages, &block) }.to yield_with_args(0, messages)
    end
  end
end
