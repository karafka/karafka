# frozen_string_literal: true

RSpec.describe Karafka::Backends::Inline do
  subject(:consumer) { consumer_class.new }

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:topic) { instance_double(Karafka::Routing::Topic, name: rand.to_s) }

  before do
    consumer_class.include(described_class)
    allow(consumer_class).to receive(:topic).and_return(topic)
  end

  it 'expect to call' do
    expect(consumer).to receive(:consume)
    consumer.call
  end
end
