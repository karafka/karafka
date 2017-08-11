# frozen_string_literal: true

RSpec.describe Karafka::Setup::Configurators::Sidekiq do
  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  subject(:sidekiq_configurator) { described_class.new(config) }

  let(:config) { double }

  describe '#setup' do
    it 'expect to configure client and server' do
      expect(sidekiq_configurator)
        .to receive(:setup_sidekiq_client)

      expect(sidekiq_configurator)
        .to receive(:setup_sidekiq_server)

      sidekiq_configurator.setup
    end
  end

  describe '#setup_sidekiq_client' do
    let(:redis_url) { rand }
    let(:client_id) { rand }
    let(:concurrency) { rand(1000) }
    let(:sidekiq_config_client) { double }
    let(:config) do
      instance_double(
        Karafka::Setup::Config.config.class,
        client_id: client_id,
        concurrency: concurrency,
        redis: {
          url: redis_url
        }
      )
    end

    before do
      expect(Sidekiq)
        .to receive(:configure_client)
        .and_yield(sidekiq_config_client)

      expect(sidekiq_config_client)
        .to receive(:redis=)
        .with(
          config.redis.merge(
            size: config.concurrency
          )
        )
    end

    it { sidekiq_configurator.send(:setup_sidekiq_client) }
  end

  describe '#setup_sidekiq_server' do
    let(:redis_url) { rand }
    let(:name) { rand }
    let(:concurrency) { rand(1000) }
    let(:sidekiq_config_server) { double }
    let(:config) do
      instance_double(
        Karafka::Setup::Config.config.class,
        redis: {
          url: redis_url
        }
      )
    end

    before do
      expect(Sidekiq)
        .to receive(:configure_server)
        .and_yield(sidekiq_config_server)

      expect(sidekiq_config_server)
        .to receive(:redis=)
        .with(config.redis)
    end

    it { sidekiq_configurator.send(:setup_sidekiq_server) }
  end
end
