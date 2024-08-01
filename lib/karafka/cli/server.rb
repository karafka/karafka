# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli
    # Server Karafka Cli action
    class Server < Base
      include Helpers::ConfigImporter.new(
        activity_manager: %i[internal routing activity_manager]
      )

      # Types of things we can include / exclude from the routing via the CLI options
      SUPPORTED_TYPES = ::Karafka::Routing::ActivityManager::SUPPORTED_TYPES

      private_constant :SUPPORTED_TYPES

      desc 'Starts the Karafka server (short-cut aliases: "s", "consumer")'

      aliases :s, :consumer

      # Those options can also be used when in swarm mode, hence we re-use
      OPTIONS_BUILDER = lambda do
        option(
          :consumer_groups,
          'Runs server only with specified consumer groups',
          Array,
          %w[
            -g
            --consumer_groups
            --include_consumer_groups
          ]
        )

        option(
          :subscription_groups,
          'Runs server only with specified subscription groups',
          Array,
          %w[
            --subscription_groups
            --include_subscription_groups
          ]
        )

        option(
          :topics,
          'Runs server only with specified topics',
          Array,
          %w[
            --topics
            --include_topics
          ]
        )

        option(
          :exclude_consumer_groups,
          'Runs server without specified consumer groups',
          Array,
          %w[
            --exclude_consumer_groups
          ]
        )

        option(
          :exclude_subscription_groups,
          'Runs server without specified subscription groups',
          Array,
          %w[
            --exclude_subscription_groups
          ]
        )

        option(
          :exclude_topics,
          'Runs server without specified topics',
          Array,
          %w[
            --exclude_topics
          ]
        )
      end

      instance_exec(&OPTIONS_BUILDER)

      # Start the Karafka server
      def call
        # Print our banner and info in the dev mode
        print_marketing_info if Karafka::App.env.development?

        register_inclusions
        register_exclusions

        Karafka::Server.execution_mode = :standalone
        Karafka::Server.run
      end

      # Registers things we want to include (if defined)
      def register_inclusions
        SUPPORTED_TYPES.each do |type|
          names = options[type] || []

          names.each { |name| activity_manager.include(type, name) }
        end
      end

      # Registers things we want to exclude (if defined)
      def register_exclusions
        activity_manager.class::SUPPORTED_TYPES.each do |type|
          names = options[:"exclude_#{type}"] || []

          names.each { |name| activity_manager.exclude(type, name) }
        end
      end
    end
  end
end
