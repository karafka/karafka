# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      nodes: nodes
    )
  end

  let(:active) { true }
  let(:nodes) { [0, 1, 2] }

  describe '#active?' do
    context 'when active' do
      it 'returns true' do
        expect(config.active?).to be(true)
      end
    end

    context 'when not active' do
      let(:active) { false }

      it 'returns false' do
        expect(config.active?).to be(false)
      end
    end
  end

  describe '#nodes' do
    context 'with multiple nodes' do
      it 'returns all nodes' do
        expect(config.nodes).to contain_exactly(0, 1, 2)
      end
    end

    context 'with no nodes' do
      let(:nodes) { [] }

      it 'returns an empty array' do
        expect(config.nodes).to be_empty
      end
    end
  end
end
