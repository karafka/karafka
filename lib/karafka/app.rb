# frozen_string_literal: true

module Karafka
  # App class
  class App
    extend Setup::Dsl

    class << self
      # Sets up all the internal components and bootstrap whole app
      # We need to know details about consumers in order to setup components,
      # that's why we don't setup them after std setup is done
      # @raise [Karafka::Errors::InvalidConfigurationError] raised when configuration
      #   doesn't match with ConfigurationSchema
      def boot!
        initialize!
        Setup::Config.validate!
        Setup::Config.setup_components
        events.publish('after_init', config: Karafka::App.config)
      end

      # @return [Karafka::Routing::Builder] consumers builder instance
      def consumer_groups
        Routing::Builder.instance
      end

      Status.instance_methods(false).each do |delegated|
        define_method(delegated) do
          Status.instance.send(delegated)
        end
      end

      # Methods that should be delegated to Karafka module
      %i[
        root
        env
        logger
        monitor
        events
      ].each do |delegated|
        define_method(delegated) do
          Karafka.send(delegated)
        end
      end
    end
  end
end
