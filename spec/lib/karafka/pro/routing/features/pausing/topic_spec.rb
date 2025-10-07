# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#pausing' do
    it 'returns a Config object' do
      expect(topic.pausing).to be_a(Karafka::Pro::Routing::Features::Pausing::Config)
    end

    it 'initializes with default values' do
      expect(topic.pausing.active?).to be(false)
      expect(topic.pausing.timeout).to eq(1)
      expect(topic.pausing.max_timeout).to eq(1)
      expect(topic.pausing.with_exponential_backoff).to be(false)
      expect(topic.pausing.with_exponential_backoff?).to be(false)
    end
  end

  describe '#pausing?' do
    context 'when pause has not been called' do
      it { expect(topic.pausing?).to be(false) }
    end

    context 'when pause has been called' do
      before { topic.pause(timeout: 100) }

      it { expect(topic.pausing?).to be(true) }
    end
  end

  describe '#pause' do
    context 'when called without arguments' do
      it 'returns the pausing config' do
        expect(topic.pause).to eq(topic.pausing)
      end
    end

    context 'when setting only timeout with rest of defaults' do
      before { topic.pause(timeout: 100) }

      it 'expect to change only timeout in config' do
        expect(topic.pausing.timeout).to eq(100)
        expect(topic.pausing.max_timeout).to eq(1)
        expect(topic.pausing.with_exponential_backoff).to be(false)
        expect(topic.pausing.active?).to be(true)
      end

      it 'expect backwards compatibility with old accessors' do
        expect(topic.pause_timeout).to eq(100)
        expect(topic.pause_max_timeout).to eq(1)
        expect(topic.pause_with_exponential_backoff).to be(false)
      end
    end

    context 'when setting only max_timeout with rest of defaults' do
      before { topic.pause(max_timeout: 100) }

      it 'expect to change only max_timeout in config' do
        expect(topic.pausing.timeout).to eq(1)
        expect(topic.pausing.max_timeout).to eq(100)
        expect(topic.pausing.with_exponential_backoff).to be(false)
        expect(topic.pausing.active?).to be(true)
      end

      it 'expect backwards compatibility with old accessors' do
        expect(topic.pause_timeout).to eq(1)
        expect(topic.pause_max_timeout).to eq(100)
        expect(topic.pause_with_exponential_backoff).to be(false)
      end
    end

    context 'when setting only with_exponential_backoff with rest of defaults' do
      before { topic.pause(with_exponential_backoff: true) }

      it 'expect to change only with_exponential_backoff in config' do
        expect(topic.pausing.timeout).to eq(1)
        expect(topic.pausing.max_timeout).to eq(1)
        expect(topic.pausing.with_exponential_backoff).to be(true)
        expect(topic.pausing.with_exponential_backoff?).to be(true)
        expect(topic.pausing.active?).to be(true)
      end

      it 'expect backwards compatibility with old accessors' do
        expect(topic.pause_timeout).to eq(1)
        expect(topic.pause_max_timeout).to eq(1)
        expect(topic.pause_with_exponential_backoff).to be(true)
      end
    end

    context 'when we change all' do
      before do
        topic.pause(
          timeout: 100,
          max_timeout: 150,
          with_exponential_backoff: true
        )
      end

      it 'expect to change all in config' do
        expect(topic.pausing.timeout).to eq(100)
        expect(topic.pausing.max_timeout).to eq(150)
        expect(topic.pausing.with_exponential_backoff).to be(true)
        expect(topic.pausing.active?).to be(true)
      end

      it 'expect backwards compatibility with old accessors' do
        expect(topic.pause_timeout).to eq(100)
        expect(topic.pause_max_timeout).to eq(150)
        expect(topic.pause_with_exponential_backoff).to be(true)
      end
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h.key?(:pause_timeout)).to be(true) }
    it { expect(topic.to_h.key?(:pause_max_timeout)).to be(true) }
    it { expect(topic.to_h.key?(:pause_with_exponential_backoff)).to be(true) }
    it { expect(topic.to_h.key?(:pausing)).to be(true) }

    context 'when pause is configured' do
      before { topic.pause(timeout: 100, max_timeout: 200, with_exponential_backoff: true) }

      it 'includes pausing config hash' do
        pausing_hash = topic.to_h[:pausing]
        expect(pausing_hash[:active]).to be(true)
        expect(pausing_hash[:timeout]).to eq(100)
        expect(pausing_hash[:max_timeout]).to eq(200)
        expect(pausing_hash[:with_exponential_backoff]).to be(true)
      end
    end
  end
end
