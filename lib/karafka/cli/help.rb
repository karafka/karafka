#Karafka commands:
#  karafka console         # Start the Karafka console (short-cut alias: "c")
#  karafka help [COMMAND]  # Describe available commands or one specific command
#  karafka info            # Print configuration details and other options of your application
#  karafka install         # Install all required things for Karafka application in current directory
#  karafka server          # Start the Karafka server (short-cut alias: "s")
#  karafka topics          # Allows for the topics management (create, delete, reset, repartition)

# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli
    # Prints info with list of commands available
    class Help < Base
      desc 'Describes available commands'

      # Print available commands
      def call
        # Find the longest command for alignment purposes
        max_command_length = self.class.commands.flat_map { |command| [command.name] }.map(&:size).max

        puts 'Karafka commands:'

        # Print each command formatted with its description
        self.class.commands.each do |command|
          puts "  #{command.name.ljust(max_command_length)}    # #{command.desc}"
        end
      end
    end
  end
end
