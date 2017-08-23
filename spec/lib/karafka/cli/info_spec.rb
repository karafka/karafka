# frozen_string_literal: true

RSpec.describe Karafka::Cli::Info do
  subject(:info_cli) { described_class.new(cli) }

  let(:cli) { Karafka::Cli.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:info) do
      [
        "Karafka framework version: #{Karafka::VERSION}",
        "Application client id: #{Karafka::App.config.client_id}",
        "Processing backend: #{Karafka::App.config.processing_backend}",
        "Batch consuming: #{Karafka::App.config.batch_consuming}",
        "Batch processing: #{Karafka::App.config.batch_processing}",
        "Number of threads: #{Karafka::App.config.concurrency}",
        "Boot file: #{Karafka.boot_file}",
        "Environment: #{Karafka.env}",
        "Kafka seed brokers: #{Karafka::App.config.kafka.seed_brokers}",
        "Redis: #{Karafka::App.config.redis.to_h}"
      ]
    end

    it 'expect to print details of this Karafka app instance' do
      expect(info_cli)
        .to receive(:puts)
        .with(info.join("\n"))

      info_cli.call
    end
  end
end
