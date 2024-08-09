# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) { described_class.new(active: active) }

  describe '#active?' do
    context 'when active' do
      let(:active) { true }

      it { expect(config.active?).to eq(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to eq(false) }
    end
  end
end
