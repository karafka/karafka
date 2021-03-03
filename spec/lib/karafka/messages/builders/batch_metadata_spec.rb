# frozen_string_literal: true

RSpec.describe_current do
  let(:routing_topic) { build(:routing_topic) }
  let(:message1) { build(:kafka_fetched_message) }
  let(:message2) { build(:kafka_fetched_message) }
  let(:kafka_batch) { [message1, message2] }
  let(:scheduled_at) { Time.now }

  describe '#call' do
    subject(:result) { described_class.call(kafka_batch, routing_topic, scheduled_at) }

    it { is_expected.to be_a(Karafka::Messages::BatchMetadata) }
    it { expect(result.size).to eq kafka_batch.count }
    it { expect(result.partition).to eq kafka_batch.first.partition }
    it { expect(result.first_offset).to eq kafka_batch.first.offset }
    it { expect(result.last_offset).to eq kafka_batch.last.offset }
    it { expect(result.topic).to eq routing_topic.name }
    it { expect(result.deserializer).to eq routing_topic.deserializer }
    it { expect(result.scheduled_at).to eq(scheduled_at) }
    it { expect(result).to be_frozen }
  end
end
