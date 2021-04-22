# frozen_string_literal: true

RSpec.describe_current do
  subject(:info_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:info) do
      [
        "Karafka version: #{Karafka::VERSION}",
        "Ruby version: #{RUBY_VERSION}",
        "Rdkafka version: #{::Rdkafka::VERSION}",
        "Subscription groups count: #{Karafka::App.subscription_groups.size}",
        "Workers count: #{Karafka::App.config.concurrency}",
        "Application client id: #{Karafka::App.config.client_id}",
        "Boot file: #{Karafka.boot_file}",
        "Environment: #{Karafka.env}"
      ].join("\n")
    end

    before { allow(Karafka.logger).to receive(:info) }

    it 'expect to print details of this Karafka app instance' do
      info_cli.call
      expect(Karafka.logger).to have_received(:info).with(info)
    end
  end
end
