module Karafka
  class Configurators
    # Class responsible for setting up Celluloid settings
    class Celluloid < Base
      # Sets up a Karafka logger as celluloid logger
      def setup
        ::Celluloid.logger = ::Karafka.logger
        # The Poseidon socket timeout is 10, so we give it a bit more time to shutdown after
        # socket timeout
        ::Celluloid.shutdown_timeout = 15
      end
    end
  end
end
