# frozen_string_literal: true

RSpec.describe_current do
  subject(:partitioner) { described_class.new(subscription_group) }

  let(:subscription_group) { build(:routing_subscription_group) }
  let(:coordinator) { build(:processing_coordinator) }

  describe '#call' do
    let(:topic) { 'topic-name' }
    let(:messages) { [build(:messages_message)] }

    it 'expect to yield with 0 and input messages' do
      expect do |block|
        partitioner.call(topic, messages, coordinator, &block)
      end.to yield_with_args(0, messages)
    end
  end
end
