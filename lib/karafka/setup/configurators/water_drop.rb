# frozen_string_literal: true

module Karafka
  module Setup
    # Configurators are used to post setup some of the components of Karafka after the core
    # framework is initialized
    module Configurators
      # Class responsible for setting up WaterDrop configuration
      module WaterDrop
        class << self
          # Sets up a WaterDrop settings
          # @param config [Karafka::Setup::Config] Config we can user to setup things
          # @note This will also inject Karafka monitor as a default monitor into WaterDrop,
          #   so we have the same monitor within whole Karafka framework (same with logger)
          def call(config)
            ::WaterDrop.setup do |water_config|
              water_config.deliver = true

              config.to_h.reject { |k, _v| k == :kafka }.each do |k, v|
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
end
