RSpec.describe Karafka::Setup::Configurators::WaterDrop do
  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  let(:config) do
    instance_double(
      Karafka::Setup::Config.config.class,
      concurrency: ::Karafka::App.config.concurrency,
      kafka: instance_double(
        Karafka::Setup::Config.config.kafka.class,
        hosts: ::Karafka::App.config.kafka.hosts
      ),
      # Instance double has a private method called timeout, that's why we use
      # openstruct here
      connection_pool: OpenStruct.new(
        size: ::Karafka::App.config.connection_pool.size,
        timeout: ::Karafka::App.config.connection_pool.timeout
      )
    )
  end

  subject(:water_drop_configurator) { described_class.new(config) }

  describe '#setup' do
    it 'expect to assign waterdrop default configs' do
      water_drop_configurator.setup

      expect(WaterDrop.config.send_messages).to eq true
      expect(WaterDrop.config.connection_pool_size).to eq config.connection_pool.size
      expect(WaterDrop.config.connection_pool_timeout).to eq config.connection_pool.timeout
      expect(WaterDrop.config.kafka.hosts).to eq config.kafka.hosts
      expect(WaterDrop.config.raise_on_failure).to eq true
    end
  end
end
