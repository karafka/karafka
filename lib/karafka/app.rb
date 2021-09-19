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
      #   doesn't match with the config contract
      def boot!
        initialized!
      end

      # @return [Karafka::Routing::Builder] consumers builder instance alias
      def consumer_groups
        config
          .internal
          .routing_builder
      end

      # @return [Array<Karafka::Routing::SubscriptionGroup>] active subscription groups
      def subscription_groups
        consumer_groups
          .active
          .flat_map(&:subscription_groups)
      end

      Status.instance_methods(false).each do |delegated|
        define_method(delegated) do
          App.config.internal.status.send(delegated)
        end
      end

      # Methods that should be delegated to Karafka module
      %i[
        root
        env
        logger
        producer
        monitor
      ].each do |delegated|
        define_method(delegated) do
          Karafka.send(delegated)
        end
      end
    end
  end
end
