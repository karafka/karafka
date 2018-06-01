# frozen_string_literal: true

RSpec.describe Karafka::Params::ParamsBatch do
  subject(:params_batch) { described_class.new(kafka_messages, topic_parser) }

  let(:unparsed_value) { { rand.to_s => rand.to_s } }
  let(:parsed_value) { unparsed_value.to_json }
  let(:create_time) { Time.now }
  let(:topic_parser) { Karafka::Parsers::Json }
  let(:kafka_messages) { [kafka_message1, kafka_message2] }
  let(:kafka_message1) do
    Kafka::FetchedMessage.new(
      message: OpenStruct.new(
        value: parsed_value,
        key: nil,
        offset: 0,
        create_time: create_time
      ),
      topic: 'topic',
      partition: 0
    )
  end

  let(:kafka_message2) do
    Kafka::FetchedMessage.new(
      message: OpenStruct.new(
        value: parsed_value,
        key: nil,
        offset: 0,
        create_time: create_time
      ),
      topic: 'topic',
      partition: 0
    )
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

  describe '#values' do
    it 'expect to return parsed values from params within params batch' do
      expect(params_batch.values).to eq [unparsed_value, unparsed_value]
    end

    context 'when values were used for the first time' do
      before { params_batch.values }

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
