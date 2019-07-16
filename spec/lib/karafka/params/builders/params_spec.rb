# frozen_string_literal: true

RSpec.describe Karafka::Params::Builders::Params do
  let(:routing_topic) { build(:routing_topic) }
  let(:fetched_message) { build(:kafka_fetched_message) }

  describe '#from_kafka_message' do
    subject(:result) { described_class.from_kafka_message(fetched_message, routing_topic) }

    it { is_expected.to be_a(Karafka::Params::Params) }
    it { expect(result.payload).to eq fetched_message.value }
    it { expect(result.partition).to eq fetched_message.partition }
    it { expect(result.offset).to eq fetched_message.offset }
    it { expect(result.key).to eq fetched_message.key }
    it { expect(result.create_time).to eq fetched_message.create_time }

    context 'when message does not have headers' do
      it { expect(result.headers).to eq({}) }
    end

    context 'when message does have headers' do
      let(:headers) { { rand => rand } }
      let(:fetched_message) { build(:kafka_fetched_message, headers: headers) }

      it { expect(result.headers).to eq headers }
    end
  end
end
