module Karafka
  # Karafka framework Cli
  class Cli
    # Console Karafka Cli action
    class Console < Base
      self.desc = 'Start the Karafka console (short-cut alias: "c")'
      self.options = { aliases: 'c' }

      # Start the Karafka console
      def call
        cli.info
        # This is a trick that will work with reload
        # If we return a exitstatus 10 from irb - it will tell us to restart this irb
        # By restarting it, it will reload all the code, so it will act similar to
        # Rails console reload! feature
        loop do
          system "KARAFKA_CONSOLE=true bundle exec irb -r #{Karafka.boot_file}"
          break unless $CHILD_STATUS.exitstatus == 10
        end
      end
    end
  end
end
