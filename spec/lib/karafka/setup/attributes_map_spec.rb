# frozen_string_literal: true

RSpec.describe_current do
  subject(:map) { described_class }

  let(:settings) do
    {
      # Producer only
      'message.send.max.retries': 1_000,
      # Consumer only
      'max.poll.interval.ms': 2_000,
      # Both
      'ssl.crl.location': ''
    }
  end

  describe '#consumer' do
    subject(:stripped) { described_class.consumer(settings) }

    it 'expect to keep consumer and shared settings' do
      expect(stripped.key?(:'message.send.max.retries')).to be(false)
      expect(stripped[:'max.poll.interval.ms']).to eq(2_000)
      expect(stripped[:'ssl.crl.location']).to eq('')
    end
  end

  describe '#producer' do
    subject(:stripped) { described_class.producer(settings) }

    it 'expect to keep producer and shared settings' do
      expect(stripped.key?(:'max.poll.interval.ms')).to be(false)
      expect(stripped[:'message.send.max.retries']).to eq(1_000)
      expect(stripped[:'ssl.crl.location']).to eq('')
    end
  end

  describe '#generate' do
    subject(:generated_list) { described_class.generate }

    it 'expect to have correct settings for both consumer and producer' do
      if Rdkafka::VERSION > '0.21'
        expect(generated_list[:consumer]).to eq(described_class::CONSUMER)
        expect(generated_list[:producer]).to eq(described_class::PRODUCER)
      else
        expect(
          (generated_list[:consumer] + %i[metadata.recovery.strategy]).sort
        ).to eq(described_class::CONSUMER)
        expect(
          (generated_list[:producer] + %i[metadata.recovery.strategy]).sort
        ).to eq(described_class::PRODUCER)
      end
    end
  end
end
