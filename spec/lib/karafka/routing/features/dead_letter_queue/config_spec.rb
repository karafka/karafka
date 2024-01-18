# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      independent: independent,
      transactional: transactional
    )
  end

  let(:independent) { false }
  let(:active) { true }
  let(:transactional) { true }

  describe '#active?' do
    context 'when active' do
      let(:active) { true }

      it { expect(config.active?).to eq(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to eq(false) }
    end
  end

  describe '#independent?' do
    context 'when independent' do
      let(:independent) { true }

      it { expect(config.independent?).to eq(true) }
    end

    context 'when not independent' do
      let(:independent) { false }

      it { expect(config.independent?).to eq(false) }
    end
  end

  describe '#transactional?' do
    context 'when independent' do
      let(:transactional) { true }

      it { expect(config.transactional?).to eq(true) }
    end

    context 'when not transactional' do
      let(:transactional) { false }

      it { expect(config.transactional?).to eq(false) }
    end
  end
end
