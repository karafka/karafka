module Karafka
  class Configurators
    # Class responsible for setting up Celluloid settings
    class Celluloid < Base
      # Sets up a Karafka logger as celluloid logger
      def setup
        # The Poseidon socket timeout is 10, so we give it a bit more time to shutdown after
        # socket timeout
        ::Celluloid.shutdown_timeout = 15
        ::Celluloid.logger = ::Karafka.logger
      end
    end
  end
end
