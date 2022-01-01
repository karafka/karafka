# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Server Karafka Cli action
    class Server < Base
      desc 'Start the Karafka server (short-cut alias: "s")'
      option aliases: 's'
      option :consumer_groups, type: :array, default: nil, aliases: :g

      # Start the Karafka server
      def call
        # Print our banner and info in the dev mode
        print_marketing_info if Karafka::App.env.development?

        Contracts::ServerCliOptions.new.validate!(cli.options)

        # We assign active topics on a server level, as only server is expected to listen on
        # part of the topics
        Karafka::Server.consumer_groups = cli.options[:consumer_groups]

        Karafka::Server.run
      end

      private

      # Prints marketing info
      def print_marketing_info
        Karafka.logger.info Info::BANNER

        if Karafka.pro?
          Karafka.logger.info(
            "\033[0;32mThank you for investing in the Karafka Pro subscription!\033[0m\n"
          )
        else
          Karafka.logger.info(
            "\033[0;31mYou like Karafka? Please consider getting a Pro subscription!\033[0m\n"
          )
        end
      end
    end
  end
end
