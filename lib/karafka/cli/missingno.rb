# frozen_string_literal: true

module Karafka
  class Cli < Thor
    # Command that gets invoked when no method is provided when running the CLI
    # It allows us to exit with exit code 1 instead of default 0 to indicate that something
    #   was missing
    # @see https://github.com/karafka/karafka/issues/619
    class Missingno < Base
      desc 'Hidden command that gets invoked when no command is provided', hide: true

      # Prints an error about the lack of command (nothing selected)
      def call
        Karafka.logger.error('No command provided')
        exit 1
      end
    end
  end
end
