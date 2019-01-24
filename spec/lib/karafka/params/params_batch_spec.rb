# frozen_string_literal: true

RSpec.describe Karafka::Params::ParamsBatch do
  subject(:params_batch) { described_class.new(params_array) }

  let(:unparsed_payload) { { rand.to_s => rand.to_s } }
  let(:parsed_payload) { unparsed_payload.to_json }
  let(:topic) { build(:routing_topic) }
  let(:kafka_message1) { build(:kafka_fetched_message, value: parsed_payload) }
  let(:kafka_message2) { build(:kafka_fetched_message, value: parsed_payload) }
  let(:params_array) do
    [
      Karafka::Params::Builders::Params.from_kafka_message(kafka_message1, topic),
      Karafka::Params::Builders::Params.from_kafka_message(kafka_message2, topic)
    ]
  end

  describe '#to_a' do
    it 'expect not to parse data and return raw params_batch' do
      expect(params_batch.to_a.first['parsed']).to eq nil
    end
  end

  describe '#parse!' do
    it 'expect to parse all the messages and return parsed' do
      params_batch.parse!
      params_batch.to_a.each { |params| expect(params['parsed']).to eq true }
    end
  end

  describe '#each' do
    it 'expect to parse each at a time' do
      params_batch.each_with_index do |params, index|
        expect(params['parsed']).to eq true
        next if index > 0

        expect(params_batch.to_a[index + 1]['parsed']).to eq nil
      end
    end
  end

  describe '#payloads' do
    it 'expect to return parsed payloads from params within params batch' do
      expect(params_batch.payloads).to eq [unparsed_payload, unparsed_payload]
    end

    context 'when payloads were used for the first time' do
      before { params_batch.payloads }

      it 'expect to mark as unparsed all the params inside the batch' do
        expect(params_batch.to_a.all? { |params| params['parsed'] }).to eq true
      end
    end
  end

  describe '#first' do
    it 'expect to return first element after parsing' do
      expect(params_batch.first).to eq params_batch.to_a[0]
      expect(params_batch.first['parsed']).to eq true
    end
  end

  describe '#last' do
    it 'expect to return last element after parsing' do
      expect(params_batch.last).to eq params_batch.to_a[-1]
      expect(params_batch.last['parsed']).to eq true
    end
  end
end
