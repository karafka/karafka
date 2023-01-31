# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Server Karafka Cli action
    class Server < Base
      include Helpers::Colorize

      # Types of things we can include / exclude from the routing via the CLI options
      SUPPORTED_TYPES = ::Karafka::Routing::ActivityManager::SUPPORTED_TYPES

      private_constant :SUPPORTED_TYPES

      desc 'Start the Karafka server (short-cut alias: "s")'

      option aliases: 's'

      # Thor does not work well with many aliases combinations, hence we remap the aliases
      # by ourselves in the code
      option :consumer_groups, type: :array, default: [], aliases: :g
      option :subscription_groups, type: :array, default: []
      option :topics, type: :array, default: []

      %i[
        include
        exclude
      ].each do |action|
        SUPPORTED_TYPES.each do |type|
          option(
            "#{action}_#{type}",
            type: :array,
            default: []
          )
        end
      end

      # Start the Karafka server
      def call
        # Print our banner and info in the dev mode
        print_marketing_info if Karafka::App.env.development?

        register_inclusions(cli)
        register_exclusions(cli)

        Karafka::Server.run
      end

      private

      # Registers things we want to include (if defined)
      # @param cli [Karafka::Cli] Thor cli handler
      def register_inclusions(cli)
        activities = ::Karafka::App.config.internal.routing.activity_manager

        SUPPORTED_TYPES.each do |type|
          v1 = cli.options[type] || []
          v2 = cli.options[:"include_#{type}"] || []
          names = v1 + v2

          names.each { |name| activities.include(type, name) }
        end
      end

      # Registers things we want to exclude (if defined)
      # @param cli [Karafka::Cli] Thor cli handler
      def register_exclusions(cli)
        activities = ::Karafka::App.config.internal.routing.activity_manager

        activities.class::SUPPORTED_TYPES.each do |type|
          names = cli.options[:"exclude_#{type}"] || []

          names.each { |name| activities.exclude(type, name) }
        end
      end

      # Prints marketing info
      def print_marketing_info
        Karafka.logger.info Info::BANNER

        if Karafka.pro?
          Karafka.logger.info(
            green('Thank you for using Karafka Pro!')
          )
        else
          Karafka.logger.info(
            red('Upgrade to Karafka Pro for more features and support: https://karafka.io')
          )
        end
      end
    end
  end
end
