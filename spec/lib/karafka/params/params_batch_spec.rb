# frozen_string_literal: true

RSpec.describe Karafka::Params::ParamsBatch do
  subject(:params_batch) { described_class.new(kafka_messages, topic_parser) }

  let(:value) { {}.to_json }
  let(:create_time) { Time.now }
  let(:topic_parser) { Karafka::Parsers::Json }
  let(:kafka_messages) { [kafka_message1, kafka_message2] }
  let(:kafka_message1) do
    instance_double(
      Kafka::FetchedMessage,
      topic: 'topic',
      value: value,
      key: nil,
      partition: 0,
      offset: 0,
      create_time: create_time
    )
  end
  let(:kafka_message2) do
    instance_double(
      Kafka::FetchedMessage,
      topic: 'topic',
      value: value,
      key: nil,
      partition: 0,
      offset: 0,
      create_time: create_time
    )
  end

  describe '#to_a' do
    it 'expect not to parse data and return raw params_batch' do
      expect(params_batch.to_a.first[:parsed]).to eq false
    end
  end

  describe '#parsed' do
    it 'expect to parse all the messages and return parsed' do
      params_batch.parsed
      params_batch.to_a.each { |params| expect(params[:parsed]).to eq true }
    end
  end

  describe '#each' do
    it 'expect to parse each at a time' do
      params_batch.each_with_index do |params, index|
        expect(params[:parsed]).to eq true
        next if index > 0
        expect(params_batch.to_a[index + 1][:parsed]).to eq false
      end
    end
  end
end
