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
            water_config.deliver = true
            water_config.logger = Karafka::App.config.logger
            water_config.client_id = Karafka::App.config.client_id

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
