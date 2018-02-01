# frozen_string_literal: true

module Karafka
  module Setup
    class Configurators
      # Class responsible for setting up WaterDrop configuration
      class WaterDrop < Base
        # Sets up a WaterDrop settings
        # @param config [Karafka::Setup::Config] Config we can user to setup things
        def self.setup(config)
          ::WaterDrop.setup do |water_config|
            water_config.deliver = true

            config.to_h.except(:kafka).each do |k, v|
              key_assignment = :"#{k}="
              next unless water_config.respond_to?(key_assignment)
              water_config.public_send(key_assignment, v)
            end

            config.kafka.to_h.each do |k, v|
              key_assignment = :"#{k}="
              next unless water_config.kafka.respond_to?(key_assignment)
              water_config.kafka.public_send(key_assignment, v)
            end
          end
        end
      end
    end
  end
end
