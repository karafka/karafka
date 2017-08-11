# frozen_string_literal: true

module Karafka
  module Setup
    class Configurators
      # Class responsible for setting up WaterDrop configuration
      class WaterDrop < Base
        # Sets up a WaterDrop settings
        def setup
          dynamic_params = Connection::ConfigAdapter.client(nil)

          ::WaterDrop.setup do |water_config|
            water_config.send_messages = true
            water_config.raise_on_failure = true
            water_config.connection_pool = config.connection_pool

            # Automigration of all the attributes that should be accepted by waterdrop
            # based on what we use in karafka ruby-kafka initialization
            dynamic_params.each do |key, value|
              key_assignment = :"#{key}="
              # We decide whether we should set it on a kafka scope of waterdrop config or on the
              # main scope
              scope = water_config.kafka.respond_to?(key_assignment) ? :kafka : :itself
              water_config.public_send(scope).public_send(key_assignment, value)
            end
          end
        end
      end
    end
  end
end
