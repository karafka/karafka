# frozen_string_literal: true

module Karafka
  module Setup
    # Configurators module is used to enclose all the external dependencies configurations
    # upon which Karafka depents
    class Configurators
      # Karafka has some components that it relies on (like Sidekiq)
      # We need to configure all of them only when the framework was set up.
      # Any class that descends from this one will be automatically invoked upon setup (after it)
      # @note This should be used only for internal Karafka dependencies configuration
      #   End users configuration should go to the after_init block
      # @example Configure an Example class
      #   class ExampleConfigurator < Base
      #     def setup
      #       ExampleClass.logger = Karafka.logger
      #       ExampleClass.redis = config.redis
      #     end
      #   end
      class Base
        # @param _config [Karafka::Config] config instance
        # This method needs to be implemented in a subclass
        def self.setup(_config)
          raise NotImplementedError
        end
      end
    end
  end
end
