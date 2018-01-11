# frozen_string_literal: true

RSpec.describe Karafka::Backends::Inline do
  subject(:consumer) { consumer_class.new }

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }

  before { consumer_class.include(described_class) }

  it 'expect to call' do
    expect(consumer).to receive(:consume)
    consumer.call
  end
end
