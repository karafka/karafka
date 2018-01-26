# frozen_string_literal: true

RSpec.describe Karafka::Callbacks::Dsl do
  # App gets dsl, so it is easier to test against it
  subject(:app_class) { Karafka::App }

  describe '#after_init' do
    let(:execution_block) { ->(_config) {} }

    it 'expects to assing a block into internal settings array' do
      app_class.after_init(&execution_block)
      expect(app_class.config.internal.after_init).to include execution_block
    end
  end
end
