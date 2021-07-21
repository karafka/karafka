# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::WaterDrop do
  subject(:water_drop_configurator) { described_class.new }

  let(:config) { Karafka::App.config }

  describe '.call' do
    before do
      config.kafka.idempotent = true
      config.kafka.transactional = true
      config.kafka.transactional_timeout = 1337
      water_drop_configurator.call(config)
    end

    it { expect(WaterDrop.config.deliver).to eq true }
    it { expect(WaterDrop.config.kafka.seed_brokers).to eq config.kafka.seed_brokers }
    it { expect(WaterDrop.config.logger).to eq Karafka::App.logger }
    it { expect(WaterDrop.config.kafka.idempotent).to eq(true) }
    it { expect(WaterDrop.config.kafka.transactional).to eq(true) }
    it { expect(WaterDrop.config.kafka.transactional_timeout).to eq(1337) }
  end
end
