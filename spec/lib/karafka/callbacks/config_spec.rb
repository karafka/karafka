# frozen_string_literal: true

RSpec.describe Karafka::Callbacks::Config do
  describe 'after_init settings' do
    subject(:callbacks) { Karafka::App.config.callbacks }

    it { expect(callbacks.after_init).to be_a(Array) }
  end

  describe 'before_fetch_loop settings' do
    subject(:callbacks) { Karafka::App.config.callbacks }

    it { expect(callbacks.before_fetch_loop).to be_a(Array) }
  end
end
