# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      timeout: timeout,
      max_timeout: max_timeout,
      with_exponential_backoff: with_exponential_backoff
    )
  end

  let(:active) { true }
  let(:timeout) { 1_000 }
  let(:max_timeout) { 5_000 }
  let(:with_exponential_backoff) { true }

  describe '#active?' do
    context 'when active is true' do
      let(:active) { true }

      it { expect(config.active?).to be(true) }
    end

    context 'when active is false' do
      let(:active) { false }

      it { expect(config.active?).to be(false) }
    end
  end

  describe '#with_exponential_backoff?' do
    context 'when with_exponential_backoff is true' do
      let(:with_exponential_backoff) { true }

      it { expect(config.with_exponential_backoff?).to be(true) }
    end

    context 'when with_exponential_backoff is false' do
      let(:with_exponential_backoff) { false }

      it { expect(config.with_exponential_backoff?).to be(false) }
    end
  end

  describe '#timeout' do
    it { expect(config.timeout).to eq(timeout) }
  end

  describe '#max_timeout' do
    it { expect(config.max_timeout).to eq(max_timeout) }
  end

  describe '#to_h' do
    it 'returns a hash with all config attributes' do
      hash = config.to_h
      expect(hash[:active]).to eq(active)
      expect(hash[:timeout]).to eq(timeout)
      expect(hash[:max_timeout]).to eq(max_timeout)
      expect(hash[:with_exponential_backoff]).to eq(with_exponential_backoff)
    end
  end
end
