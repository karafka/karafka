# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) { described_class.new(factories: factories) }

  describe '#active?' do
    context 'when there are factories' do
      let(:factories) { [1] }

      it { expect(config.active?).to eq(true) }
    end

    context 'when there are no factories' do
      let(:factories) { [] }

      it { expect(config.active?).to eq(false) }
    end
  end

  describe '#to_h' do
    let(:factories) { [1] }

    it { expect(config.to_h[:factories]).to eq(factories) }
    it { expect(config.to_h[:active]).to eq(true) }
  end
end
