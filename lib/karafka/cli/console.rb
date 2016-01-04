module Karafka
  # Karafka framework Cli
  class Cli
    desc 'console', 'Start the Karafka console (short-cut alias: "c")'
    method_option :console, aliases: 'c'
    def console
      # This is a trick that will work with reload
      # If we return a exitstatus 10 from irb - it will tell us to restart this irb
      # By restarting it, it will reload all the code, so it will act similar to
      # Rails console reload! feature
      loop do
        system 'KARAFKA_CONSOLE=true irb -r ./app.rb'
        break unless $CHILD_STATUS.exitstatus == 10
      end
    end
  end
end
