# frozen_string_literal: true

RSpec.describe_current do
  subject(:info_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    context 'when running info on lgpl' do
      let(:info) do
        [
          "Karafka version: #{Karafka::VERSION}",
          "Ruby version: #{RUBY_DESCRIPTION}",
          "Rdkafka version: #{::Rdkafka::VERSION}",
          "Consumer groups count: #{Karafka::App.consumer_groups.size}",
          "Subscription groups count: #{Karafka::App.subscription_groups.values.flatten.size}",
          "Workers count: #{Karafka::App.config.concurrency}",
          "Application client id: #{Karafka::App.config.client_id}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}",
          'License: LGPL-3.0'
        ].join("\n")
      end

      before do
        Karafka::App.config.license.token = false
        allow(Karafka.logger).to receive(:info)
      end

      it 'expect to print details of this Karafka app instance' do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(described_class::BANNER)
        expect(Karafka.logger).to have_received(:info).with(info)
      end
    end

    context 'when running info on pro' do
      let(:info) do
        [
          "Karafka version: #{Karafka::VERSION} + Pro",
          "Ruby version: #{RUBY_DESCRIPTION}",
          "Rdkafka version: #{::Rdkafka::VERSION}",
          "Consumer groups count: #{Karafka::App.consumer_groups.size}",
          "Subscription groups count: #{Karafka::App.subscription_groups.values.flatten.size}",
          "Workers count: #{Karafka::App.config.concurrency}",
          "Application client id: #{Karafka::App.config.client_id}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}",
          'License: Commercial',
          "License entity: #{Karafka::App.config.license.entity}"
        ].join("\n")
      end

      before do
        Karafka::App.config.license.token = true
        Karafka::App.config.license.entity = rand.to_s

        allow(Karafka.logger).to receive(:info)
      end

      after do
        Karafka::App.config.license.token = false
        Karafka::App.config.license.entity = ''
      end

      it 'expect to print details of this Karafka app instance' do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(described_class::BANNER)
        expect(Karafka.logger).to have_received(:info).with(info)
      end
    end
  end
end
