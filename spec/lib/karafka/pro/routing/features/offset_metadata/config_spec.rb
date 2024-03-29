# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      deserializer: deserializer,
      cache: cache
    )
  end

  let(:active) { true }
  let(:cache) { true }
  let(:deserializer) { ->(arg) { arg.to_s } }

  describe '#active?' do
    context 'when active' do
      it { expect(config.active?).to eq(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to eq(false) }
    end
  end

  describe '#cache?' do
    context 'when cache' do
      it { expect(config.cache?).to eq(true) }
    end

    context 'when not cache' do
      let(:cache) { false }

      it { expect(config.cache?).to eq(false) }
    end
  end
end
