module Karafka
  # Karafka framework Cli
  class Cli
    # Server Karafka Cli action
    class Server < Base
      self.desc = 'Start the Karafka server (short-cut alias: "s")'
      self.options = { aliases: 's' }

      # Start the Karafka server
      def call
        puts 'Starting Karafka framework server'
        cli.info

        Karafka::Server.run
      end
    end
  end
end
