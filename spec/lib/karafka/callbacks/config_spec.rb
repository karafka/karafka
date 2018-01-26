# frozen_string_literal: true

RSpec.describe Karafka::Callbacks::Config do
  context 'after_init settings' do
    subject(:internal) { Karafka::App.config.internal }

    it { expect(internal.after_init).to be_a(Array) }
  end
end
