# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) { described_class.new(active: active, interval: interval) }

  let(:active) { true }
  let(:interval) { 1_000 }

  describe '#active?' do
    context 'when active' do
      it { expect(config.active?).to be(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to be(false) }
    end
  end
end
