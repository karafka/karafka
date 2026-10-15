# frozen_string_literal: true

module Karafka
  class Cli
    # Console Karafka Cli action
    class Console < Base
      desc 'Starts the Karafka console (short-cut alias: "c")'

      aliases :c

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
          "bundle exec rails console"
        end
      end

      # Start the Karafka console
      def call
        rails = Karafka.rails?

        unless rails || irb_available?
          puts "#{red("Karafka console needs the irb gem.")} Add `gem \"irb\"` to your Gemfile."
          exit(1)
        end

        Info.new.call

        command = rails ? self.class.rails_console : self.class.console

        exec "KARAFKA_CONSOLE=true #{command}"
      end

      private

      # @return [Boolean] true if `bundle exec irb` can find irb
      # @note Since Ruby 4.0 irb is a bundled gem, so in a Bundler context it is available only
      #   when listed in the Gemfile. Rails brings it as a railties dependency.
      def irb_available?
        Gem.bin_path("irb", "irb")
        true
      rescue Gem::Exception, Gem::LoadError
        false
      end
    end
  end
end
