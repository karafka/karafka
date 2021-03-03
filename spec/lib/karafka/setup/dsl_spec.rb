# frozen_string_literal: true

RSpec.describe_current do
  # App gets dsl, so it is easier to test against it
  subject(:app_class) { Karafka::App }

  describe '#config' do
    let(:config) { double }

    before do
      allow(Karafka::Setup::Config)
        .to receive(:config)
        .and_return(config)
    end

    it 'aliases to Config' do
      expect(app_class.config).to eq config

      expect(Karafka::Setup::Config).to have_received(:config)
    end
  end

  describe '#setup' do
    before do
      allow(Karafka::Setup::Config).to receive(:setup)
      app_class.setup
    end

    it 'delegates it to Config setup and set framework to initializing state' do
      expect(Karafka::Setup::Config).to have_received(:setup)
    end
  end
end
