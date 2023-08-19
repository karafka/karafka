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

  describe 'types values' do
    context 'when placeholder' do
      let(:type) { :placeholder }

      it { expect(config.placeholder?).to eq(true) }
      it { expect(config.discovered?).to eq(false) }
      it { expect(config.regular?).to eq(false) }
    end

    context 'when discovered' do
      let(:type) { :discovered }

      it { expect(config.placeholder?).to eq(false) }
      it { expect(config.discovered?).to eq(true) }
      it { expect(config.regular?).to eq(false) }
    end

    context 'when regular' do
      let(:type) { :regular }

      it { expect(config.placeholder?).to eq(false) }
      it { expect(config.discovered?).to eq(false) }
      it { expect(config.regular?).to eq(true) }
    end
  end

  describe '#to_h' do
    it { expect(config.to_h[:type]).to eq(type) }
    it { expect(config.to_h[:active]).to eq(true) }
  end
end
