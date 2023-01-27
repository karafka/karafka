# frozen_string_literal: true

module Karafka
  # Karafka framework Cli
  class Cli < Thor
    # Console Karafka Cli action
    class Console < Base
      desc 'Start the Karafka console (short-cut alias: "c")'
      option aliases: 'c'

      class << self
        # @return [String] Console executing command for non-Rails setup
        # @example
        #   Karafka::Cli::Console.command #=> 'KARAFKA_CONSOLE=true bundle exec irb...'
        def console
          "IRBRC='#{Karafka.gem_root}/.console_irbrc' bundle exec irb -r #{Karafka.boot_file}"
        end

        # @return [String] Console executing command for Rails setup
        # @note In case of Rails, it has its own console, hence we can just defer to it
        def rails_console
          'bundle exec rails console'
        end
      end

      # Start the Karafka console
      def call
        cli.info

        command = ::Karafka.rails? ? self.class.rails_console : self.class.console

        exec "KARAFKA_CONSOLE=true #{command}"
      end
    end
  end
end
