# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  # If you want to add/modify command that belongs to CLI, please review all commands
  # available in cli/ directory inside Karafka source code.
  #
  # @note Whole Cli is built using Thor
  # @see https://github.com/erikhuda/thor
  class Cli < Thor
    package_name 'Karafka'

    class << self
      # Loads all Cli commands into Thor framework
      # This method should be executed before we run Karafka::Cli.start, otherwise we won't
      # have any Cli commands available
      def prepare
        cli_commands.each do |action|
          action.bind_to(self)
        end
      end

      private

      # @return [Array<Class>] Array with Cli action classes that can be used as commands
      def cli_commands
        constants
          .map! { |object| const_get(object) }
          .keep_if do |object|
            object.instance_of?(Class) && (object < Cli::Base)
          end
      end
    end
  end
end

# This is kinda trick - since we don't have a autoload and other magic stuff
# like Rails does, so instead this method allows us to replace currently running
# console with a new one via Kernel.exec. It will start console with new code loaded
# Yes we know that it is not turbofast, however it is turbo convinient and small
#
# Also - the KARAFKA_CONSOLE is used to detect that we're executing the irb session
# so this method is only available when the Karafka console is running
#
# We skip this because this should exist and be only valid in the console
# :nocov:
if ENV['KARAFKA_CONSOLE']
  # Reloads Karafka irb console session
  def reload!
    puts "Reloading...\n"
    Kernel.exec Karafka::Cli::Console.command
  end
end
# :nocov:
