# frozen_string_literal: true

RSpec.describe Karafka::Setup::Dsl do
  # App gets dsl, so it is easier to test against it
  subject(:app_class) { Karafka::App }

  describe '#config' do
    let(:config) { double }

    it 'aliases to Config' do
      expect(Karafka::Setup::Config)
        .to receive(:config)
        .and_return(config)

      expect(app_class.config).to eq config
    end
  end

  describe '#setup' do
    it 'delegates it to Config setup and set framework to initializing state' do
      expect(Karafka::Setup::Config).to receive(:setup).once

      app_class.setup
    end
  end
end
