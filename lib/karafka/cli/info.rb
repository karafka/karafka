# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli
    # Info Karafka Cli action
    class Info < Base
      include Helpers::ConfigImporter.new(
        concurrency: %i[concurrency],
        license: %i[license],
        client_id: %i[client_id]
      )

      desc 'Prints configuration details and other options of your application'

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
        postfix = Karafka.pro? ? ' + Pro' : ''

        [
          "Karafka version: #{Karafka::VERSION}#{postfix}",
          "Ruby version: #{RUBY_DESCRIPTION}",
          "Rdkafka version: #{::Rdkafka::VERSION}",
          "Consumer groups count: #{Karafka::App.consumer_groups.size}",
          "Subscription groups count: #{Karafka::App.subscription_groups.values.flatten.size}",
          "Workers count: #{concurrency}",
          "Application client id: #{client_id}",
          "Boot file: #{Karafka.boot_file}",
          "Environment: #{Karafka.env}"
        ]
      end

      # @return [Array<String>] license related info
      def license_info
        if Karafka.pro?
          [
            'License: Commercial',
            "License entity: #{license.entity}"
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
