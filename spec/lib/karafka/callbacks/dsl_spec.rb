# frozen_string_literal: true

RSpec.describe Karafka::Callbacks::Dsl do
  # App gets dsl, so it is easier to test against it
  subject(:app_class) { Karafka::App }

  describe '#after_init' do
    let(:execution_block) { ->(_config) {} }

    it 'expects to assing a block into internal settings array' do
      app_class.after_init(&execution_block)
      expect(app_class.config.callbacks.after_init).to include execution_block
    end
  end

  describe '#before_fetch_loop' do
    let(:execution_block) { ->(_consumer_group, _client) {} }

    it 'expects to assing a block into internal settings array' do
      app_class.before_fetch_loop(&execution_block)
      expect(app_class.config.callbacks.before_fetch_loop).to include execution_block
    end
  end
end
