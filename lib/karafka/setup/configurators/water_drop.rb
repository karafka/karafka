# frozen_string_literal: true

module Karafka
  module Setup
    # Configurators are used to post setup some of the components of Karafka after the core
    # framework is initialized
    module Configurators
      # Class responsible for setting up WaterDrop configuration
      class WaterDrop
        # Sets up a WaterDrop settings
        # @param config [Karafka::Setup::Config] Config we can user to setup things
        # @note This will also inject Karafka monitor as a default monitor into WaterDrop,
        #   so we have the same monitor within whole Karafka framework (same with logger)
        def call(config)
          return
        end
      end
    end
  end
end
