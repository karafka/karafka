module Karafka
  module Setup
    class Configurators
      # Class responsible for setting up Celluloid settings
      class Celluloid < Base
        # How many seconds should we wait for actors (listeners) before forcefully shutting them
        SHUTDOWN_TIME = 30

        # Sets up a Karafka logger as celluloid logger
        def setup
          ::Celluloid.logger = ::Karafka.logger
          # This is just a precaution - it should automatically close the current
          # connection and shutdown actor - but in case it didn't (hanged, etc)
          # we will kill it after waiting for some time
          ::Celluloid.shutdown_timeout = SHUTDOWN_TIME
        end
      end
    end
  end
end
