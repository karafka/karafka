# frozen_string_literal: true

RSpec.describe Karafka::Callbacks do
  describe 'config extensions' do
    subject(:callbacks) { Karafka::App.config.callbacks }

    it { expect(callbacks.after_init).to be_a(Array) }
  end

  describe '#after_init' do
    subject(:callbacks) { described_class }

    before { Karafka::App.config.callbacks.after_init << ->(_config) {} }

    it 'expect to call the after_init blocks' do
      expect(Karafka::App.config.callbacks.after_init.first)
        .to receive(:call).with(Karafka::App.config)

      callbacks.after_init(Karafka::App.config)
    end
  end

  describe '#before_fetch_loop' do
    subject(:callbacks) { described_class }

    let(:arg1) { rand }
    let(:arg2) { rand }

    before { Karafka::App.config.callbacks.before_fetch_loop << ->(_arg1, _arg2) {} }

    it 'expect to call the before_fetch_loop blocks' do
      expect(Karafka::App.config.callbacks.before_fetch_loop.first)
        .to receive(:call).with(arg1, arg2)

      callbacks.before_fetch_loop(arg1, arg2)
    end
  end
end
