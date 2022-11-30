# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Server Karafka Cli action
    class Server < Base
      include Helpers::Colorize

      desc 'Start the Karafka server (short-cut alias: "s")'
      option aliases: 's'
      option :consumer_groups, type: :array, default: [], aliases: :g
      option :subscription_groups, type: :array, default: []
      option :topics, type: :array, default: []

      # Start the Karafka server
      def call
        # Print our banner and info in the dev mode
        print_marketing_info if Karafka::App.env.development?

        active_routing_config = Karafka::App.config.internal.routing.active
        active_routing_config.consumer_groups = cli.options[:consumer_groups]
        active_routing_config.subscription_groups = cli.options[:subscription_groups]
        active_routing_config.topics = cli.options[:topics]

        Karafka::Server.run
      end

      private

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
