# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Server Karafka Cli action
    class Server < Base
      # Server config settings contract
      CONTRACT = Contracts::ServerCliOptions.new.freeze

      private_constant :CONTRACT

      desc 'Start the Karafka server (short-cut alias: "s")'
      option aliases: 's'
      option :consumer_groups, type: :array, default: nil, aliases: :g

      # Start the Karafka server
      def call
        cli.info

        validate!

        # We assign active topics on a server level, as only server is expected to listen on
        # part of the topics
        Karafka::Server.consumer_groups = cli.options[:consumer_groups]

        Karafka::Server.run
      end

      private

      # Checks the server cli configuration
      # options validations in terms of app setup (topics, pid existence, etc)
      def validate!
        result = CONTRACT.call(cli.options)
        return if result.success?

        raise Errors::InvalidConfigurationError, result.errors.to_h
      end
    end
  end
end
