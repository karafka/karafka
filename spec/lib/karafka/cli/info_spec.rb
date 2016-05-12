require 'spec_helper'

RSpec.describe Karafka::Cli::Info do
  let(:cli) { Karafka::Cli.new }
  subject { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:info) do
      [
        "Karafka framework version: #{Karafka::VERSION}",
        "Application name: #{Karafka::App.config.name}",
        "Max number of threads: #{Karafka::App.config.max_concurrency}",
        "Boot file: #{Karafka.boot_file}",
        "Environment: #{Karafka.env}",
        "Kafka hosts: #{Karafka::App.config.kafka.hosts}",
        "Zookeeper hosts: #{Karafka::App.config.zookeeper.hosts}",
        "Redis: #{Karafka::App.config.redis}",
        "Wait timeout: #{Karafka::App.config.wait_timeout}"
      ]
    end

    it 'expect to print details of this Karafka app instance' do
      expect(subject)
        .to receive(:puts)
        .with(info.join("\n"))

      subject.call
    end
  end
end
