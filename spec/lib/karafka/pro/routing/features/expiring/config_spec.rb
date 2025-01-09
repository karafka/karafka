# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) { described_class.new(ttl: ttl, active: active) }

  let(:ttl) { 1 }
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

  describe '#to_h' do
    it { expect(config.to_h[:ttl]).to eq(ttl) }
    it { expect(config.to_h[:active]).to be(true) }
  end
end
