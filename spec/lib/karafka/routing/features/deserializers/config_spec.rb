# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      key: key,
      headers: headers
    )
  end

  let(:active) { true }
  let(:key) { rand }
  let(:payload) { rand }
  let(:headers) { rand }

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
