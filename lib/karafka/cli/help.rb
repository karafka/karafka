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
        max_command_length = self.class.commands.map(&:name).map(&:size).max

        puts 'Karafka commands:'

        # Print each command formatted with its description
        self.class.commands.each do |command|
          puts "  #{command.name.ljust(max_command_length)}    # #{command.desc}"
        end
      end
    end
  end
end
