module Karafka
  module Setup
    class Configurators
      # Class responsible for setting up WorkerGlass settings
      class WorkerGlass < Base
        # Sets up a Karafka logger as celluloid logger
        def setup
          ::WorkerGlass.logger = ::Karafka.logger
        end
      end
    end
  end
end
