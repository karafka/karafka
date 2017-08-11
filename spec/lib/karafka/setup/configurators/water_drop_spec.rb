# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::WaterDrop do
  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  subject(:water_drop_configurator) { described_class.new(config) }

  let(:config) do
    instance_double(
      Karafka::Setup::Config.config.class,
      client_id: ::Karafka::App.config.client_id,
      kafka: OpenStruct.new(
        seed_brokers: ::Karafka::App.config.kafka.seed_brokers
      ),
      # Instance double has a private method called timeout, that's why we use
      # openstruct here
      connection_pool: OpenStruct.new(
        size: ::Karafka::App.config.connection_pool.size,
        timeout: ::Karafka::App.config.connection_pool.timeout
      )
    )
  end

  describe '#setup' do
    before { water_drop_configurator.setup }

    it { expect(WaterDrop.config.send_messages).to eq true }
    it { expect(WaterDrop.config.connection_pool.size).to eq config.connection_pool.size }
    it { expect(WaterDrop.config.connection_pool.timeout).to eq config.connection_pool.timeout }
    it { expect(WaterDrop.config.kafka.seed_brokers).to eq config.kafka.seed_brokers }
    it { expect(WaterDrop.config.logger).to eq Karafka::App.logger }
    it { expect(WaterDrop.config.raise_on_failure).to eq true }
  end
end
