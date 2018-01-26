# frozen_string_literal: true

RSpec.describe Karafka::Callbacks::Config do
  context 'after_init settings' do
    subject(:internal) { Karafka::App.config.internal }

    it { expect(internal.after_init).to be_a(Array) }
  end

  context 'before_fetch_loop settings' do
    subject(:internal) { Karafka::App.config.internal }

    it { expect(internal.before_fetch_loop).to be_a(Array) }
  end
end
