# frozen_string_literal: true

RSpec.describe Karafka::Backends::Inline do
  subject(:consumer) { consumer_class.new }

  let(:topic) { instance_double(Karafka::Routing::Topic, name: rand.to_s) }
  let(:consumer_class) do
    ClassBuilder.inherit(Karafka::BaseConsumer) do
      def consume
        123
      end
    end
  end

  before do
    consumer_class.include(described_class)
    allow(consumer_class).to receive(:topic).and_return(topic)
  end

  it 'expect to call' do
    # This is the value returned from the #consume method. We check the result instead
    # of stubbing the subject and expecting the invocation
    expect(consumer.call).to eq 123
  end
end
