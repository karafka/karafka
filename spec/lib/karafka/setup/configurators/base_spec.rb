# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::Base do
  subject(:base_configurator) { described_class }

  describe '.setup' do
    it { expect { base_configurator.setup({}) }.to raise_error(NotImplementedError) }
  end
end
