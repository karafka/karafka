# frozen_string_literal: true

RSpec.describe Karafka::Consumers::Metadata do
  subject(:consumer) { consumer_class.new(topic) }

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:metadata) { Karafka::Params::Metadata.new }
  let(:topic) { build(:routing_topic) }

  before do
    consumer.extend(described_class)
    consumer.metadata = metadata
  end

  it 'expect to provide #metadata' do
    expect(consumer.send(:metadata)).to eq metadata
  end

  it 'expect to provide #metadata=' do
    expect(consumer).to respond_to(:metadata=)
  end
end
