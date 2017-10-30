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
        "Backend: #{Karafka::App.config.backend}",
        "Batch fetching: #{Karafka::App.config.batch_fetching}",
        "Batch consuming: #{Karafka::App.config.batch_consuming}",
        "Boot file: #{Karafka.boot_file}",
        "Environment: #{Karafka.env}",
        "Kafka seed brokers: #{Karafka::App.config.kafka.seed_brokers}"
      ]
    end

    it 'expect to print details of this Karafka app instance' do
      expect { info_cli.call }.to output(info.join("\n") + "\n").to_stdout
    end
  end
end
