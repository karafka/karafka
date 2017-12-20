# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::WaterDrop do
  subject(:water_drop_configurator) { described_class }

  let(:config) { Karafka::App.config }

  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  describe '.setup' do
    before { water_drop_configurator.setup(config) }

    it { expect(WaterDrop.config.deliver).to eq true }
    it { expect(WaterDrop.config.kafka.seed_brokers).to eq config.kafka.seed_brokers }
    it { expect(WaterDrop.config.logger).to eq Karafka::App.logger }
  end
end
