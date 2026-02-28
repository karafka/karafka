# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) do
    described_class.new(
      active: active,
      key: key,
      headers: headers,
      parallel: parallel
    )
  end

  let(:active) { true }
  let(:key) { rand }
  let(:payload) { rand }
  let(:headers) { rand }
  let(:parallel) { false }

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

  describe '#parallel?' do
    context 'when parallel is false on topic' do
      let(:parallel) { false }

      it { expect(config.parallel?).to be(false) }
    end

    context 'when parallel is true on topic but globally disabled' do
      let(:parallel) { true }

      before do
        allow(Karafka::App.config.deserializing.parallel).to receive(:active).and_return(false)
      end

      it { expect(config.parallel?).to be(false) }
    end

    context 'when parallel is true on topic and globally enabled' do
      let(:parallel) { true }

      before do
        allow(Karafka::App.config.deserializing.parallel).to receive(:active).and_return(true)
      end

      it { expect(config.parallel?).to be(true) }
    end

    context 'when called multiple times' do
      let(:parallel) { true }

      before do
        allow(Karafka::App.config.deserializing.parallel).to receive(:active).and_return(true)
      end

      it 'caches the result' do
        config.parallel?
        config.parallel?
        expect(Karafka::App.config.deserializing.parallel).to have_received(:active).once
      end
    end
  end
end
