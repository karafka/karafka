require 'spec_helper'

RSpec.describe Karafka::Cli do
  subject { described_class.new }

  describe '#info' do
    let(:info) do
      [
        "Karafka framework version: #{Karafka::VERSION}",
        "Application name: #{Karafka::App.config.name}",
        "Max number of threads: #{Karafka::App.config.max_concurrency}",
        "Boot file: #{Karafka.boot_file}",
        "Environment: #{Karafka.env}",
        "Kafka hosts: #{Karafka::App.config.kafka_hosts}",
        "Zookeeper hosts: #{Karafka::App.config.zookeeper_hosts}",
        "Redis: #{Karafka::App.config.redis}",
        "Worker timeout: #{Karafka::App.config.worker_timeout}"
      ]
    end

    it 'expect to print details of this Karafka app instance' do
      expect(subject)
        .to receive(:puts)
        .with(info.join("\n"))

      subject.info
    end
  end
end
