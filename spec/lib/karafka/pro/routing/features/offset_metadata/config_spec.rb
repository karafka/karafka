# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      deserializer: deserializer,
      cache: cache
    )
  end

  let(:active) { true }
  let(:cache) { true }
  let(:deserializer) { ->(arg) { arg.to_s } }

  describe '#active?' do
    context 'when active' do
      it { expect(config.active?).to be(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to be(false) }
    end
  end

  describe '#cache?' do
    context 'when cache' do
      it { expect(config.cache?).to be(true) }
    end

    context 'when not cache' do
      let(:cache) { false }

      it { expect(config.cache?).to be(false) }
    end
  end
end
