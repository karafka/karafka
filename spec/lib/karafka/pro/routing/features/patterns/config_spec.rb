# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) { described_class.new(type: type, active: active) }

  let(:type) { 1 }
  let(:active) { true }

  describe '#active?' do
    context 'when active' do
      it { expect(config.active?).to eq(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(config.to_h[:type]).to eq(type) }
    it { expect(config.to_h[:active]).to eq(true) }
  end
end
