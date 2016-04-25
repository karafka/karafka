module Karafka
  module Setup
    # Configurators module is used to enclose all the external dependencies configurations
    class Configurators
      # Karafka has come components that it relies on (like Celluloid or Sidekiq)
      # We need to configure all of them only when the framework was set up.
      # Any class that descends from this one will be automatically invoked upon setup (after it)
      # @example Configure an Example class
      #   class ExampleConfigurator < Base
      #     def setup
      #       ExampleClass.logger = Karafka.logger
      #       ExampleClass.redis = config.redis
      #     end
      #   end
      class Base
        extend ActiveSupport::DescendantsTracker

        attr_reader :config

        # @param config [Karafka::Config] config instance
        # @return [Karafka::Config::Base] configurator for a given component
        def initialize(config)
          @config = config
        end

        # This method needs to be implemented in a subclass
        def setup
          raise NotImplementedError
        end
      end
    end
  end
end
