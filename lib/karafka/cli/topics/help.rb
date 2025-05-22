# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Declarative topics CLI sub-help
      class Help < Base
        # Displays help information for all available topics management commands
        def call
          puts <<~HELP
            Karafka topics commands:
              align        # Aligns configuration of all declarative topics based on definitions
              create       # Creates topics with appropriate settings
              delete       # Deletes all topics defined in the routes
              help         # Describes available topics management commands
              migrate      # Creates missing topics, repartitions existing and aligns configuration
              plan         # Plans migration process and prints changes to be applied
              repartition  # Adds additional partitions to topics with fewer partitions than expected
              reset        # Deletes and re-creates all topics

            Options:
              --detailed-exitcode  # Provides detailed exit codes (0=no changes, 1=error, 2=changes applied)

            Examples:
              karafka topics create
              karafka topics plan --detailed-exitcode
              karafka topics migrate
              karafka topics align

            Note: All admin operations run on the default cluster only.
          HELP

          # We return false to indicate with exit code 0 that no changes were applied
          false
        end
      end
    end
  end
end
