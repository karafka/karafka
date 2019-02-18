# frozen_string_literal: true

RSpec.describe Karafka::Consumers::SingleParams do
  subject(:consumer) { consumer_class.new(topic) }

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:params_batch) { [{ 'value' => {}.to_json }] }
  let(:topic) { build(:routing_topic) }

  before do
    consumer.extend(described_class)
    consumer.params_batch = params_batch
  end

  it 'expect to provide #params' do
    expect(consumer.send(:params)).to eq consumer.send(:params_batch).first
  end

  it 'expect not to deserialize the value inside' do
    expect(consumer.send(:params)['deserialized']).to be nil
  end
end
