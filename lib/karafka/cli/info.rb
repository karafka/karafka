# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Info Karafka Cli action
    class Info < Base
      desc 'Print configuration details and other options of your application'

      # Nice karafka banner
      BANNER = <<~BANNER

        @@@                                             @@@@@  @@@
        @@@                                            @@@     @@@
        @@@  @@@    @@@@@@@@@   @@@ @@@   @@@@@@@@@  @@@@@@@@  @@@  @@@@   @@@@@@@@@
        @@@@@@     @@@    @@@   @@@@@    @@@    @@@    @@@     @@@@@@@    @@@    @@@
        @@@@@@@    @@@    @@@   @@@     @@@@    @@@    @@@     @@@@@@@    @@@    @@@
        @@@  @@@@  @@@@@@@@@@   @@@      @@@@@@@@@@    @@@     @@@  @@@@   @@@@@@@@@@

      BANNER

      # Print configuration details and other options of your application
      def call
        Karafka.logger.info(BANNER)
        Karafka.logger.info((core_info + license_info).join("\n"))
      end

      private

      # @return [Array<String>] core framework related info
      def core_info
        config = Karafka::App.config

        postfix = Karafka.pro? ? ' + Pro' : ''

        [
          "Karafka version: #{Karafka::VERSION}#{postfix}",
          "Ruby version: #{RUBY_VERSION}",
          "Rdkafka version: #{::Rdkafka::VERSION}",
          "Subscription groups count: #{Karafka::App.subscription_groups.size}",
          "Workers count: #{Karafka::App.config.concurrency}",
          "Application client id: #{config.client_id}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}"
        ]
      end

      # @return [Array<String>] license related info
      def license_info
        config = Karafka::App.config

        if Karafka.pro?
          [
            'License: Commercial',
            "License entity: #{config.license.entity}",
            "License expires on: #{config.license.expires_on}"
          ]
        else
          [
            'License: LGPL-3.0'
          ]
        end
      end
    end
  end
end
