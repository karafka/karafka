# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      min: min,
      max: max
    )
  end

  let(:active) { true }
  let(:min) { 1 }
  let(:max) { 1 }

  describe '#active?' do
    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to be(false) }
    end

    context 'when active' do
      let(:active) { true }

      it { expect(config.active?).to be(true) }
    end
  end
end
