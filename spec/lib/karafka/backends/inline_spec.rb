# frozen_string_literal: true

RSpec.describe Karafka::Backends::Inline do
  subject(:consumer) { consumer_class.new(topic) }

  let(:consumer_group) { Karafka::Routing::ConsumerGroup.new(rand) }
  let(:topic) { build(:routing_topic) }
  let(:consumer_class) do
    ClassBuilder.inherit(Karafka::BaseConsumer) do
      def consume
        123
      end
    end
  end

  before { consumer.extend(described_class) }

  it 'expect to call' do
    # This is the value returned from the #consume method. We check the result instead
    # of stubbing the subject and expecting the invocation
    expect(consumer.call).to eq 123
  end
end
