module Karafka
  # Karafka framework Cli
  class Cli
    # Info Karafka Cli action
    class Info < Base
      self.desc = 'Print configuration details and other options of your application'

      # Print configuration details and other options of your application
      def call
        info = [
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

        puts(info.join("\n"))
      end
    end
  end
end
