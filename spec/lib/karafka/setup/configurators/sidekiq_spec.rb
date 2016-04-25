require 'spec_helper'

RSpec.describe Karafka::Setup::Configurators::Sidekiq do
  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  let(:config) { double }
  subject { described_class.new(config) }

  describe '#setup' do
    it 'expect to configure client and server' do
      expect(subject)
        .to receive(:setup_sidekiq_client)

      expect(subject)
        .to receive(:setup_sidekiq_server)

      subject.setup
    end
  end

  describe '#setup_sidekiq_client' do
    let(:redis_url) { rand }
    let(:name) { rand }
    let(:max_concurrency) { rand(1000) }
    let(:sidekiq_config_client) { double }
    let(:config) do
      double(
        name: name,
        max_concurrency: max_concurrency,
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
            size: config.max_concurrency
          )
        )
    end

    it { subject.send(:setup_sidekiq_client) }
  end

  describe '#setup_sidekiq_server' do
    let(:redis_url) { rand }
    let(:name) { rand }
    let(:concurrency) { rand(1000) }
    let(:sidekiq_config_server) { double }
    let(:config) do
      double(
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

    it { subject.send(:setup_sidekiq_server) }
  end
end
