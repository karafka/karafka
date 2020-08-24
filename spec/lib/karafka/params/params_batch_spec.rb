# frozen_string_literal: true

RSpec.describe Karafka::Params::ParamsBatch do
  subject(:params_batch) { described_class.new(params_array) }

  let(:deserialized_payload) { { rand.to_s => rand.to_s } }
  let(:serialized_payload) { deserialized_payload.to_json }
  let(:topic) { build(:routing_topic) }
  let(:kafka_message1) { build(:kafka_fetched_message, value: serialized_payload) }
  let(:kafka_message2) { build(:kafka_fetched_message, value: serialized_payload) }
  let(:params_array) do
    [
      Karafka::Params::Builders::Params.from_kafka_message(kafka_message1, topic),
      Karafka::Params::Builders::Params.from_kafka_message(kafka_message2, topic)
    ]
  end

  describe '#to_a' do
    it 'expect not to deserialize data and return raw params_batch' do
      expect(params_batch.to_a.first.deserialized?).to eq false
    end
  end

  describe '#deserialize!' do
    it 'expect to deserialize all the messages and return deserialized' do
      params_batch.deserialize!
      params_batch.to_a.each { |params| expect(params.deserialized?).to eq true }
    end
  end

  describe '#each' do
    it 'expect not to deserialize each at a time' do
      params_batch.each_with_index do |params, index|
        expect(params.deserialized?).to eq false
        next if index > 0

        expect(params_batch.to_a[index + 1].deserialized?).to eq false
      end
    end
  end

  describe '#payloads' do
    it 'expect to return deserialized payloads from params within params batch' do
      expect(params_batch.payloads).to eq [deserialized_payload, deserialized_payload]
    end

    context 'when payloads were used for the first time' do
      before { params_batch.payloads }

      it 'expect to mark as serialized all the params inside the batch' do
        expect(params_batch.to_a.all?(&:deserialized?)).to eq true
      end
    end
  end

  describe '#first' do
    it 'expect to return first element without deserializing' do
      expect(params_batch.first).to eq params_batch.to_a[0]
      expect(params_batch.first.deserialized?).to eq false
    end
  end

  describe '#last' do
    it 'expect to return last element without deserializing' do
      expect(params_batch.last).to eq params_batch.to_a[-1]
      expect(params_batch.last.deserialized?).to eq false
    end
  end

  describe '#size' do
    it { expect(params_batch.size).to eq params_batch.to_a.size }
  end
end
