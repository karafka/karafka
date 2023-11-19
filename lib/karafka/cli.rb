# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  #
  # If you want to add/modify command that belongs to CLI, please review all commands
  # available in cli/ directory inside Karafka source code.
  class Cli
    class << self
      # Starts the CLI
      def start
        # Command we want to run, like install, server, etc
        command_name = ARGV[0]
        # Action for action-based commands like topics migrate
        action = ARGV[1].to_s.start_with?('-') ? false : ARGV[1]

        command = commands.find { |cmd| cmd.names.include?(command_name) }

        if command
          # Only actionable commands require command as an argument
          args = action ? [action] : []

          command.new.call(*args)
        else
          raise(
            Karafka::Errors::UnrecognizedCommandError,
            "Unrecognized command \"#{command_name}\""
          )
        end
      end

      private

      # @return [Array<Class>] command classes
      def commands
        Base.commands
      end
    end
  end
end

# This is kinda tricky - since we don't have an autoload and other magic stuff
# like Rails does, so instead this method allows us to replace currently running
# console with a new one via Kernel.exec. It will start console with new code loaded
# Yes, we know that it is not turbo fast, however it is turbo convenient and small
#
# Also - the KARAFKA_CONSOLE is used to detect that we're executing the irb session
# so this method is only available when the Karafka console is running
#
# We skip this because this should exist and be only valid in the console
# :nocov:
if ENV['KARAFKA_CONSOLE']
  # Reloads Karafka irb console session
  def reload!
    Karafka.logger.info "Reloading...\n"
    Kernel.exec Karafka::Cli::Console.command
  end
end
# :nocov:
