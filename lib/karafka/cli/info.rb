module Karafka
  # Karafka framework Cli
  class Cli
    desc 'info', 'Print configuration details and other options of your application'
    # Print configuration details and other options of your application
    def info
      info = [
        "Karafka framework version: #{Karafka::VERSION}",
        "Application name: #{Karafka::App.config.name}",
        "Number of threads: #{Karafka::App.config.concurrency}",
        "Boot file: #{Karafka.boot_file}",
        "Environment: #{Karafka.env}",
        "Kafka hosts: #{Karafka::App.config.kafka_hosts}",
        "Zookeeper hosts: #{Karafka::App.config.zookeeper_hosts}",
        "Redis: #{Karafka::App.config.redis}",
        "Worker timeout: #{Karafka::App.config.worker_timeout}"
      ]

      puts(info.join("\n"))
    end
  end
end
