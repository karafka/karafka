# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) { described_class.new(factories: factories) }

  describe '#active?' do
    context 'when there are factories' do
      let(:factories) { [1] }

      it { expect(config.active?).to be(true) }
    end

    context 'when there are no factories' do
      let(:factories) { [] }

      it { expect(config.active?).to be(false) }
    end
  end

  describe '#filters' do
    context 'when no factories are registered' do
      let(:factories) { [] }

      it { expect(config.filters).to eq([]) }
    end

    context 'when factories are registered' do
      let(:factories) do
        [
          -> { 1 },
          -> { 2 }
        ]
      end

      it 'expect to use them to build' do
        expect(config.filters).to eq([1, 2])
      end
    end
  end

  describe '#to_h' do
    let(:factories) { [1] }

    it { expect(config.to_h[:factories]).to eq(factories) }
    it { expect(config.to_h[:active]).to be(true) }
  end
end
