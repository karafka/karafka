# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli
    # Starts swarm of consumers forked from the supervisor
    class Swarm < Base
      desc 'Starts swarm of Karafka consumers with a supervisor'

      aliases :swarm

      instance_exec(&Server::OPTIONS_BUILDER)

      # Starts the swarm
      def call
        ::Karafka::Swarm.ensure_supported!

        # Print our banner and info in the dev mode
        print_marketing_info if Karafka::App.env.development?

        # This will register inclusions and exclusions in the routing, so all forks will use it
        server = Server.new
        server.register_inclusions
        server.register_exclusions

        Karafka::Server.execution_mode = :supervisor
        Karafka::Swarm::Supervisor.new.run
      end
    end
  end
end
