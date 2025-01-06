# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) { described_class.new(type: type, active: active) }

  let(:type) { 1 }
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

  describe 'types values' do
    context 'when matcher' do
      let(:type) { :matcher }

      it { expect(config.matcher?).to be(true) }
      it { expect(config.discovered?).to be(false) }
      it { expect(config.regular?).to be(false) }
    end

    context 'when discovered' do
      let(:type) { :discovered }

      it { expect(config.matcher?).to be(false) }
      it { expect(config.discovered?).to be(true) }
      it { expect(config.regular?).to be(false) }
    end

    context 'when regular' do
      let(:type) { :regular }

      it { expect(config.matcher?).to be(false) }
      it { expect(config.discovered?).to be(false) }
      it { expect(config.regular?).to be(true) }
    end
  end

  describe '#to_h' do
    it { expect(config.to_h[:type]).to eq(type) }
    it { expect(config.to_h[:active]).to be(true) }
  end
end
