# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Info Karafka Cli action
    class Info < Base
      desc 'Print configuration details and other options of your application'

      # Print configuration details and other options of your application
      def call
        config = Karafka::App.config

        info = [
          "Karafka framework version: #{Karafka::VERSION}",
          "Application client id: #{config.client_id}",
          "Backend: #{config.backend}",
          "Batch fetching: #{config.batch_fetching}",
          "Batch consuming: #{config.batch_consuming}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}",
          "Kafka seed brokers: #{config.kafka.seed_brokers}"
        ]

        puts(info.join("\n"))
      end
    end
  end
end
