# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:collapser) { described_class.new }

  it 'expect not to be collapsed by default' do
    expect(collapser.collapsed?).to be(false)
  end

  context 'when no changes to until by default and reset' do
    before { collapser.refresh!(100) }

    it { expect(collapser.collapsed?).to be(false) }
  end

  context 'when collapsed until previous offset' do
    before do
      collapser.collapse_until!(10)
      collapser.refresh!(100)
    end

    it { expect(collapser.collapsed?).to be(false) }
  end

  context 'when collapsed until future offset' do
    before do
      collapser.collapse_until!(10_000)
      collapser.refresh!(100)
    end

    it { expect(collapser.collapsed?).to be(true) }
  end

  context 'when collapsed until the offset' do
    before do
      collapser.collapse_until!(100)
      collapser.refresh!(100)
    end

    it { expect(collapser.collapsed?).to be(false) }
  end

  context 'when collapsed but not refreshed' do
    before { collapser.collapse_until!(100) }

    it { expect(collapser.collapsed?).to be(false) }
  end

  context 'when collapsed multiple times with earlier offsets' do
    before do
      collapser.collapse_until!(100)
      collapser.collapse_until!(10)
      collapser.collapse_until!(1)

      collapser.refresh!(99)
    end

    it { expect(collapser.collapsed?).to be(true) }
  end

  context 'when collapsed multiple times with earlier offsets and refresh with younger' do
    before do
      collapser.collapse_until!(100)
      collapser.collapse_until!(10)
      collapser.collapse_until!(1)

      collapser.refresh!(101)
    end

    it { expect(collapser.collapsed?).to be(false) }
  end
end
