# frozen_string_literal: true

module Karafka
  # App class
  class App
    extend Setup::Dsl

    class << self
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

      # Just a nicer name for the consumer groups
      alias routes consumer_groups

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
        pro?
      ].each do |delegated|
        define_method(delegated) do
          Karafka.send(delegated)
        end
      end
    end
  end
end
