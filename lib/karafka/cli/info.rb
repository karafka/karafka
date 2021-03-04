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
          "Karafka version: #{Karafka::VERSION}",
          "Ruby version: #{RUBY_VERSION}",
          "Rdkafka version: #{::Rdkafka::VERSION}",
          "Subscription groups count: #{Karafka::App.subscription_groups.size}",
          "Workers count: #{Karafka::App.config.concurrency}",
          "Application client id: #{config.client_id}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}"
        ]

        Karafka.logger.info(info.join("\n"))
      end
    end
  end
end
