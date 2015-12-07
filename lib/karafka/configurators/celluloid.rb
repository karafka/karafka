module Karafka
  class Configurators
    # Class responsible for setting up Celluloid settings
    class Celluloid < Base
      # Sets up a Karafka logger as celluloid logger
      def setup
        ::Celluloid.logger = ::Karafka.logger
      end
    end
  end
end
