module Karafka
  module Setup
    class Configurators
      # Class responsible for setting up WaterDrop configuration
      class WaterDrop < Base
        # Sets up a WaterDrop settings
        def setup
          ::WaterDrop.setup do |water_config|
            water_config.send_messages = true
            water_config.connection_pool_size = config.connection_pool.size
            water_config.connection_pool_timeout = config.connection_pool.timeout
            water_config.kafka.hosts = config.kafka.hosts
            water_config.raise_on_failure = true
          end
        end
      end
    end
  end
end
