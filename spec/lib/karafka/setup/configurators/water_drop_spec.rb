# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::WaterDrop do
  subject(:water_drop_configurator) { described_class.new }

  let(:config) { Karafka::App.config }

  describe '.call' do
    before { water_drop_configurator.call(config) }

    it { expect(WaterDrop.config.deliver).to eq true }
    it { expect(WaterDrop.config.kafka.seed_brokers).to eq config.kafka.seed_brokers }
    it { expect(WaterDrop.config.logger).to eq Karafka::App.logger }
  end
end
