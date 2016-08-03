require 'spec_helper'

RSpec.describe Karafka::Cli::Info do
  let(:cli) { Karafka::Cli.new }
  subject(:info_cli) { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:info) do
      [
        "Karafka framework version: #{Karafka::VERSION}",
        "Application name: #{Karafka::App.config.name}",
        "Max number of threads: #{Karafka::App.config.max_concurrency}",
        "Boot file: #{Karafka.boot_file}",
        "Environment: #{Karafka.env}",
        "Zookeeper hosts: #{Karafka::App.config.zookeeper.hosts}",
        "Zookeeper chroot: #{Karafka::App.config.zookeeper.chroot}",
        "Zookeeper brokers_path: #{Karafka::App.config.zookeeper.brokers_path}",
        "Kafka hosts: #{Karafka::App.config.kafka.hosts}",
        "Redis: #{Karafka::App.config.redis.to_h}",
        "Wait timeout: #{Karafka::App.config.wait_timeout}"
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
