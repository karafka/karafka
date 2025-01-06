# frozen_string_literal: true

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
