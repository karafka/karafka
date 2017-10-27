# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::WaterDrop do
  subject(:water_drop_configurator) { described_class.new(config) }

  let(:config) do
    instance_double(
      Karafka::Setup::Config.config.class,
      client_id: ::Karafka::App.config.client_id,
      kafka: OpenStruct.new(
        seed_brokers: ::Karafka::App.config.kafka.seed_brokers
      )
    )
  end

  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  describe '#setup' do
    before { water_drop_configurator.setup }

    it { expect(WaterDrop.config.send_messages).to eq true }
    it { expect(WaterDrop.config.kafka.seed_brokers).to eq config.kafka.seed_brokers }
    it { expect(WaterDrop.config.logger).to eq Karafka::App.logger }
  end
end
