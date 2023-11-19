# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) { described_class.new(active: active, required: required) }

  let(:active) { true }
  let(:required) { true }

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

  describe '#required?' do
    context 'when required' do
      let(:required) { true }

      it { expect(config.required?).to eq(true) }
    end

    context 'when not required' do
      let(:required) { false }

      it { expect(config.required?).to eq(false) }
    end
  end
end
