# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:config) { described_class.new(active: active, required: required) }

  let(:active) { true }
  let(:required) { true }

  describe '#active?' do
    context 'when active' do
      let(:active) { true }

      it { expect(config.active?).to be(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to be(false) }
    end
  end

  describe '#required?' do
    context 'when required' do
      let(:required) { true }

      it { expect(config.required?).to be(true) }
    end

    context 'when not required' do
      let(:required) { false }

      it { expect(config.required?).to be(false) }
    end
  end
end
