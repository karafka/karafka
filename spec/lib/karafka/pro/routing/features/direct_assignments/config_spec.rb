# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) { described_class.new(active: active, partitions: partitions) }

  let(:active) { true }
  let(:partitions) { [1, 2, 3] }

  describe '#active?' do
    context 'when active' do
      it 'returns true' do
        expect(config.active?).to be true
      end
    end

    context 'when not active' do
      let(:active) { false }

      it 'returns false' do
        expect(config.active?).to be false
      end
    end
  end

  describe '#to_h' do
    it 'returns a hash representation with active and partitions keys' do
      expect(config.to_h).to eq({ active: active, partitions: partitions })
    end
  end
end
