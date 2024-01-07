# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      count: count,
      dynamic: dynamic
    )
  end

  let(:active) { true }
  let(:count) { 1 }
  let(:dynamic) { false }

  describe '#active?' do
    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to eq(false) }
    end

    context 'when active' do
      let(:active) { true }

      it { expect(config.active?).to eq(true) }
    end
  end
end
