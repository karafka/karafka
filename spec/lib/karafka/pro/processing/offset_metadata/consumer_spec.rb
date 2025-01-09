# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:consumer) { Class.new { include Karafka::Pro::Processing::OffsetMetadata::Consumer }.new }
  let(:topic) { build(:routing_topic) }
  let(:partition) { 5 }
  let(:fetcher) { Karafka::Pro::Processing::OffsetMetadata::Fetcher }

  before do
    allow(consumer).to receive_messages(
      topic: topic,
      partition: partition
    )
  end

  describe '#offset_metadata' do
    context 'when assignment is revoked' do
      before { allow(consumer).to receive(:revoked?).and_return(true) }

      it { expect(consumer.offset_metadata).to be(false) }
    end

    context 'when assignment is active' do
      let(:result) { rand }

      before do
        allow(consumer).to receive(:revoked?).and_return(false)
        allow(fetcher).to receive(:find).and_return(result)
      end

      it 'expect to reach out to fetcher' do
        expect(consumer.offset_metadata).to eq(result)
        expect(fetcher).to have_received(:find).with(topic, partition, cache: true)
      end
    end
  end

  describe '#committed_offset_metadata' do
    it do
      expect(consumer.method(:offset_metadata)).to eq(consumer.method(:committed_offset_metadata))
    end
  end
end
