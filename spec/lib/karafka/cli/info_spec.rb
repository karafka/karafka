RSpec.describe Karafka::Cli::Info do
  let(:cli) { Karafka::Cli.new }
  subject(:info_cli) { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:info) do
      [
        "Karafka framework version: #{Karafka::VERSION}",
        "Application name: #{Karafka::App.config.name}",
        "Inline mode: #{Karafka::App.config.inline}",
        "Number of threads: #{Karafka::App.config.concurrency}",
        "Boot file: #{Karafka.boot_file}",
        "Environment: #{Karafka.env}",
        "Kafka hosts: #{Karafka::App.config.kafka.hosts}",
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
