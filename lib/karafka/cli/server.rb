module Karafka
  # Karafka framework Cli
  class Cli
    desc 'server', 'Start the Karafka server (short-cut alias: "s")'
    method_option :server, aliases: 's'
    # Start the Karafka server
    def server
      puts 'Starting Karafka framework'
      info

      Karafka::App.run
    end
  end
end
