# frozen_string_literal: true

RSpec.describe Karafka::Params::Builders::Metadata do
  let(:routing_topic) { build(:routing_topic) }
  let(:kafka_batch) { build(:kafka_fetched_batch) }

  describe '#from_kafka_batch' do
    subject(:result) { described_class.from_kafka_batch(kafka_batch, routing_topic) }

    it { is_expected.to be_a(Karafka::Params::Metadata) }
    it { expect(result.batch_size).to eq kafka_batch.messages.count }
    it { expect(result.partition).to eq kafka_batch.partition }
    it { expect(result.offset_lag).to eq kafka_batch.offset_lag }
    it { expect(result.last_offset).to eq kafka_batch.last_offset }
    it { expect(result.highwater_mark_offset).to eq kafka_batch.highwater_mark_offset }
    it { expect(result.unknown_last_offset?).to eq kafka_batch.unknown_last_offset? }
    it { expect(result.first_offset).to eq kafka_batch.first_offset }
  end
end
