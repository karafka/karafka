module Karafka
  module Setup
    class Configurators
      # Class responsible for setting up Celluloid settings
      class Celluloid < Base
        # Sets up a Karafka logger as celluloid logger
        def setup
          ::Celluloid.logger = ::Karafka.logger
          # This is just a precaution - it should automatically close the current
          # connection and shutdown actor - but in case it didn't (hanged, etc)
          # we will kill it after waiting for some time
          ::Celluloid.shutdown_timeout = ::Karafka::App.config.wait_timeout * 2
        end
      end
    end
  end
end
