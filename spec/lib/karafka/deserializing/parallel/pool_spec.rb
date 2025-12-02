# frozen_string_literal: true

RSpec.describe_current do
  subject(:pool) { described_class.instance }

  before { pool.reset! }

  describe '#initialize' do
    it 'starts with size 0' do
      expect(pool.size).to eq(0)
    end

    it 'starts not started' do
      expect(pool.started?).to be(false)
    end
  end

  describe '#started?' do
    context 'when pool is not started' do
      it 'returns false' do
        expect(pool.started?).to be(false)
      end
    end

    # Skipped until Ruby 4.0 stable - Ractor warnings treated as errors in spec_helper
    context 'when pool is started', skip: 'Requires Ruby 4.0 stable with Ractors' do
      before { pool.start(2) }

      it 'returns true' do
        expect(pool.started?).to be(true)
      end
    end
  end

  describe '#size' do
    it 'returns 0 when not started' do
      expect(pool.size).to eq(0)
    end
  end

  describe '#dispatch_async' do
    let(:deserializer) { Class.new { def call(message); end }.new }
    let(:messages) do
      Array.new(10) do |i|
        instance_double(
          Karafka::Messages::Message,
          raw_payload: "payload_#{i}" * 100
        )
      end
    end

    context 'when messages array is empty' do
      it 'returns Immediate' do
        result = pool.dispatch_async([], deserializer)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end

    context 'when pool is not started' do
      it 'returns Immediate' do
        result = pool.dispatch_async(messages, deserializer)
        expect(result).to be_a(Karafka::Deserializing::Parallel::Immediate)
      end
    end

    # Threshold tests are covered by integration tests in:
    # - spec/integrations/deserialization/parallel/thresholds_spec.rb
    # - spec/integrations/deserialization/parallel/nil_payloads_spec.rb
  end
end
