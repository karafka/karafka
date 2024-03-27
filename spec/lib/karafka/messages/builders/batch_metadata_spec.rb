# frozen_string_literal: true

RSpec.describe_current do
  let(:routing_topic) { build(:routing_topic) }
  let(:message1) { build(:kafka_fetched_message, timestamp: 5.seconds.ago) }
  let(:message2) { build(:kafka_fetched_message, timestamp: 3.seconds.ago) }
  let(:kafka_batch) { [message1, message2] }
  let(:scheduled_at) { Time.now - 1.second }
  let(:partition) { rand(10) }

  describe '#call' do
    subject(:result) { described_class.call(kafka_batch, routing_topic, partition, scheduled_at) }

    let(:now) { Time.now }

    before { allow(Time).to receive(:now).and_return(now) }

    it { is_expected.to be_a(Karafka::Messages::BatchMetadata) }
    it { expect(result.size).to eq kafka_batch.count }
    it { expect(result.partition).to eq partition }
    it { expect(result.first_offset).to eq kafka_batch.first.offset }
    it { expect(result.last_offset).to eq kafka_batch.last.offset }
    it { expect(result.topic).to eq routing_topic.name }
    it { expect(result.deserializers).to eq routing_topic.deserializers }
    it { expect(result.scheduled_at).to eq(scheduled_at) }

    it 'expect to have processed_at set to nil, since not yet picked up' do
      expect(result.processed_at).to eq(nil)
    end

    context 'when processed_at is assigned to the build metadata' do
      before { result.processed_at = Time.now }

      it { expect(result.consumption_lag).to be_between(3000, 3100) }
      it { expect(result.processing_lag).to be_between(1000, 1100) }
    end

    context 'when there are no messages in the messages array' do
      let(:kafka_batch) { [] }

      it { is_expected.to be_a(Karafka::Messages::BatchMetadata) }
      it { expect(result.size).to eq 0 }
      it { expect(result.partition).to eq partition }
      it { expect(result.first_offset).to eq(-1001) }
      it { expect(result.last_offset).to eq(-1001) }
      it { expect(result.topic).to eq routing_topic.name }
      it { expect(result.deserializers).to eq routing_topic.deserializers }
      it { expect(result.scheduled_at).to eq(scheduled_at) }
    end

    context 'when building with messages from the future (time drift)' do
      before { allow(message2).to receive(:timestamp).and_return(now + 100) }

      it 'expect to use current machine now as the batch should not come from the future' do
        expect(result.created_at).to eq(now)
      end
    end
  end
end
