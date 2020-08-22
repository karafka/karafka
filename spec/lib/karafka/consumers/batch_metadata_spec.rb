# frozen_string_literal: true

RSpec.describe Karafka::Consumers::BatchMetadata do
  subject(:consumer) { consumer_class.new(topic) }

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:batch_metadata) { Karafka::Params::BatchMetadata.new }
  let(:topic) { build(:routing_topic) }

  before do
    consumer.extend(described_class)
    consumer.batch_metadata = batch_metadata
  end

  it 'expect to provide #batch_metadata' do
    expect(consumer.send(:batch_metadata)).to eq batch_metadata
  end

  it 'expect to provide #batch_metadata=' do
    expect(consumer).to respond_to(:batch_metadata=)
  end
end
