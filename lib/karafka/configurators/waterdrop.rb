module Karafka
  class Configurators
    # Class responsible for setting up WaterDrop configuration
    class WaterDrop < Base
      # Sets up a WaterDrop settings
      def setup
        ::WaterDrop.setup do |config|
          config.send_messages = true
          config.connection_pool_size = ::Karafka::App.config.concurrency
          config.connection_pool_timeout = 1
          config.kafka_hosts = ::Karafka::App.config.kafka_hosts
          config.raise_on_failure = true
        end
      end
    end
  end
end
