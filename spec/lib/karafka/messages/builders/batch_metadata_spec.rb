# frozen_string_literal: true

RSpec.describe_current do
  let(:routing_topic) { build(:routing_topic) }
  let(:message1) { build(:kafka_fetched_message, timestamp: 5.seconds.ago) }
  let(:message2) { build(:kafka_fetched_message, timestamp: 3.seconds.ago) }
  let(:kafka_batch) { [message1, message2] }
  let(:scheduled_at) { Time.now - 1.second }

  describe '#call' do
    subject(:result) { described_class.call(kafka_batch, routing_topic, scheduled_at) }

    let(:now) { Time.now }

    before { allow(Time).to receive(:now).and_return(now) }

    it { is_expected.to be_a(Karafka::Messages::BatchMetadata) }
    it { expect(result.size).to eq kafka_batch.count }
    it { expect(result.partition).to eq kafka_batch.first.partition }
    it { expect(result.first_offset).to eq kafka_batch.first.offset }
    it { expect(result.last_offset).to eq kafka_batch.last.offset }
    it { expect(result.topic).to eq routing_topic.name }
    it { expect(result.deserializer).to eq routing_topic.deserializer }
    it { expect(result.scheduled_at).to eq(scheduled_at) }

    it 'expect to have processed_at set to nil, since not yet picked up' do
      expect(result.processed_at).to eq(nil)
    end

    context 'when processed_at is assigned to the build metadata' do
      before { result.processed_at = Time.now }

      it { expect(result.consumption_lag).to be_between(3000, 3100) }
      it { expect(result.processing_lag).to be_between(1000, 1100) }
    end
  end
end
