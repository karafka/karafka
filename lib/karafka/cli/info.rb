module Karafka
  # Karafka framework Cli
  class Cli
    # Info Karafka Cli action
    class Info < Base
      desc 'Print configuration details and other options of your application'

      # Print configuration details and other options of your application
      def call
        config = Karafka::App.config

        info = [
          "Karafka framework version: #{Karafka::VERSION}",
          "Application name: #{config.name}",
          "Inline mode: #{config.inline}",
          "Number of threads: #{config.concurrency}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}",
          "Kafka hosts: #{config.kafka.hosts}",
          "Redis: #{config.redis.to_h}"
        ]

        puts(info.join("\n"))
      end
    end
  end
end
