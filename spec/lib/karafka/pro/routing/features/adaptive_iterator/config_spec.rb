# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) { described_class.new(safety_margin: safety_margin, active: active) }

  let(:safety_margin) { 1 }
  let(:active) { true }

  describe '#active?' do
    context 'when active' do
      it { expect(config.active?).to be(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to be(false) }
    end
  end

  describe '#to_h' do
    it { expect(config.to_h[:safety_margin]).to eq(safety_margin) }
    it { expect(config.to_h[:active]).to be(true) }
  end
end
