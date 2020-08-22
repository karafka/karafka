# frozen_string_literal: true

RSpec.describe Karafka::Consumers::SingleParams do
  subject(:consumer) { consumer_class.new(topic) }

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }

  let(:params_batch) { Karafka::Params::ParamsBatch.new(params_array) }
  let(:deserialized_payload) { { rand.to_s => rand.to_s } }
  let(:serialized_payload) { deserialized_payload.to_json }
  let(:topic) { build(:routing_topic) }
  let(:kafka_message) { build(:kafka_fetched_message, value: serialized_payload) }
  let(:params_array) do
    [
      Karafka::Params::Builders::Params.from_kafka_message(kafka_message, topic)
    ]
  end

  before do
    consumer.extend(described_class)
    consumer.params_batch = params_batch
  end

  it 'expect to provide #params' do
    expect(consumer.send(:params)).to eq consumer.send(:params_batch).to_a.first
  end

  it 'expect not to deserialize the value inside' do
    expect(consumer.send(:params).deserialized?).to eq false
  end
end
