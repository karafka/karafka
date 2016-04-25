module Karafka
  module Setup
    class Configurators
      # Class responsible for setting up Karafka app internals
      # @note Since this configuration configurs internal Karafka stuff, it needs to run first
      class Internals < Base
        # Sets up a Karafka internals based on settings provided by user when configuring his app
        def setup
          Karafka.logger = config.logger
          Karafka.monitor = config.monitor
        end
      end
    end
  end
end
