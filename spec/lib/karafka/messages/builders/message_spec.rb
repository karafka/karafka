# frozen_string_literal: true

RSpec.describe_current do
  let(:routing_topic) { build(:routing_topic) }
  let(:fetched_message) { build(:kafka_fetched_message) }
  let(:received_at) { Time.now }

  describe '#call' do
    subject(:result) { described_class.call(fetched_message, routing_topic, received_at) }

    it { is_expected.to be_a(Karafka::Messages::Message) }
    it { expect(result.raw_payload).to eq fetched_message.payload }
    it { expect(result.payload).to eq fetched_message.payload.to_f }
    it { expect(result.metadata.partition).to eq fetched_message.partition }
    it { expect(result.partition).to eq fetched_message.partition }
    it { expect(result.metadata.offset).to eq fetched_message.offset }
    it { expect(result.offset).to eq fetched_message.offset }
    it { expect(result.metadata.key).to eq fetched_message.key }
    it { expect(result.key).to eq fetched_message.key }
    it { expect(result.metadata.timestamp).to eq fetched_message.timestamp }
    it { expect(result.timestamp).to eq fetched_message.timestamp }
    it { expect(result.received_at).to eq received_at }

    context 'when message does not have headers' do
      it { expect(result.metadata.headers).to eq({}) }
      it { expect(result.headers).to eq({}) }
    end

    context 'when message does have headers' do
      let(:headers) { { rand => rand } }
      let(:fetched_message) { build(:kafka_fetched_message, headers: headers) }

      it { expect(result.metadata.headers).to eq headers }
      it { expect(result.headers).to eq headers }
    end
  end
end
