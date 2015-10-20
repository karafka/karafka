require 'spec_helper'

RSpec.describe Karafka::App do
  subject { described_class }

  describe '#run' do
    it 'should run in supervision, start consuming and sleep' do
      expect(subject)
        .to receive(:initialize!)

      expect(subject)
        .to receive(:sleep)

      expect(subject)
        .to receive(:run!)

      expect_any_instance_of(Karafka::Runner)
        .to receive(:run)

      expect(Karafka::Monitor.instance)
        .to receive(:supervise)
        .and_yield

      expect(Karafka::Monitor.instance)
        .to receive(:on_sigint)

      expect(Karafka::Monitor.instance)
        .to receive(:on_sigquit)

      subject.run
    end

    it 'should define a proper action for sigint' do
      expect(Karafka::Monitor.instance)
        .to receive(:supervise)

      expect(Karafka::Monitor.instance)
        .to receive(:on_sigint)
        .and_yield

      expect(Karafka::Monitor.instance)
        .to receive(:on_sigquit)

      expect(subject)
        .to receive(:stop!)

      expect(subject)
        .to receive(:exit)

      subject.run
    end

    it 'should define a proper action for sigquit' do
      expect(Karafka::Monitor.instance)
        .to receive(:supervise)

      expect(Karafka::Monitor.instance)
        .to receive(:on_sigint)

      expect(Karafka::Monitor.instance)
        .to receive(:on_sigquit)
        .and_yield

      expect(subject)
        .to receive(:stop!)

      expect(subject)
        .to receive(:exit)

      subject.run
    end
  end

  describe '#config' do
    let(:config) { double }

    it 'should alias to Config' do
      expect(Karafka::Config)
        .to receive(:config)
        .and_return(config)

      expect(subject.config).to eq config
    end
  end

  describe '#setup' do
    it 'should delegate it to Config setup and execute after_setup' do
      expect(Karafka::Config)
        .to receive(:setup)
        .once

      expect(subject)
        .to receive(:after_setup)

      subject.setup
    end
  end

  describe '#after_setup' do
    let(:worker_timeout) { rand }
    let(:config) do
      double(
        worker_timeout: worker_timeout
      )
    end

    it 'should setup all options that base on the config data' do
      expect(Celluloid)
        .to receive(:logger=)
        .with(Karafka.logger)

      expect(subject)
        .to receive(:configure_sidekiq_client)

      expect(subject)
        .to receive(:configure_sidekiq_server)

      subject.send(:after_setup)
    end
  end

  describe '#configure_sidekiq_client' do
    let(:redis_url) { rand }
    let(:redis_namespace) { rand }
    let(:name) { rand }
    let(:concurrency) { rand(1000) }
    let(:sidekiq_config_client) { double }
    let(:config) do
      double(
        name: name,
        concurrency: concurrency,
        redis_url: redis_url,
        redis_namespace: redis_namespace
      )
    end

    before do
      expect(subject)
        .to receive(:config)
        .and_return(config)
        .exactly(3).times

      expect(Sidekiq)
        .to receive(:configure_client)
        .and_yield(sidekiq_config_client)

      expect(sidekiq_config_client)
        .to receive(:redis=)
        .with(
          url: config.redis_url,
          namespace: config.redis_namespace,
          size: config.concurrency
        )
    end

    it { subject.send(:configure_sidekiq_client) }
  end

  describe '#configure_sidekiq_server' do
    let(:redis_url) { rand }
    let(:redis_namespace) { rand }
    let(:name) { rand }
    let(:concurrency) { rand(1000) }
    let(:sidekiq_config_server) { double }
    let(:config) do
      double(
        name: name,
        concurrency: concurrency,
        redis_url: redis_url,
        redis_namespace: redis_namespace
      )
    end

    before do
      expect(subject)
        .to receive(:config)
        .and_return(config)
        .exactly(2).times

      expect(Sidekiq)
        .to receive(:configure_server)
        .and_yield(sidekiq_config_server)

      expect(sidekiq_config_server)
        .to receive(:redis=)
        .with(
          url: config.redis_url,
          namespace: config.redis_namespace
        )
    end

    it { subject.send(:configure_sidekiq_server) }
  end

  describe '#monitor' do
    it { expect(subject.send(:monitor)).to be_a Karafka::Monitor }
  end

  describe 'Karafka delegations' do
    %i( root env ).each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        it "should delegate #{delegation} method to Karafka module" do
          expect(Karafka)
            .to receive(delegation)
            .and_return(return_value)

          expect(subject.public_send(delegation)).to eq return_value
        end
      end
    end
  end

  describe 'Karafka::Status delegations' do
    %i( run! running? stop! ).each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        it "should delegate #{delegation} method to Karafka module" do
          expect(Karafka::Status.instance)
            .to receive(delegation)
            .and_return(return_value)

          expect(subject.public_send(delegation)).to eq return_value
        end
      end
    end
  end
end
