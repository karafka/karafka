module Karafka
  # Karafka framework Cli
  class Cli
    # Console Karafka Cli action
    class Console < Base
      self.desc = 'Start the Karafka console (short-cut alias: "c")'
      self.options = { aliases: 'c' }

      # @return [String] Console executing command
      # @example
      #   Karafka::Cli::Console.command #=> 'KARAFKA_CONSOLE=true bundle exec irb...'
      def self.command
        "KARAFKA_CONSOLE=true bundle exec irb -r #{Karafka.boot_file}"
      end

      # Start the Karafka console
      def call
        cli.info
        system self.class.command
      end
    end
  end
end
