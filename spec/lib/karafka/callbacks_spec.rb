# frozen_string_literal: true

RSpec.describe Karafka::Callbacks do
  context 'config extensions' do
    subject(:internal) { Karafka::App.config.internal }

    it { expect(internal.after_init).to be_a(Array) }
  end

  describe '#after_init' do
    subject(:callbacks) { described_class }

    before {  Karafka::App.config.internal.after_init << ->(_config) {} }

    it 'expect to call the after_init blocks' do
      expect(Karafka::App.config.internal.after_init.first)
        .to receive(:call).with(Karafka::App.config)

      callbacks.after_init(Karafka::App.config)
    end
  end
end
