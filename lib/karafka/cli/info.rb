# frozen_string_literal: true

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
          "Inline mode: #{config.inline_mode}",
          "Batch consuming: #{config.batch_consuming}",
          "Batch processing: #{config.batch_processing}",
          "Number of threads: #{config.concurrency}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}",
          "Kafka seed brokers: #{config.kafka.seed_brokers}",
          "Redis: #{config.redis.to_h}"
        ]

        puts(info.join("\n"))
      end
    end
  end
end
