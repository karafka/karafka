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
          .routing
          .builder
      end

      # @return [Hash] active subscription groups grouped based on consumer group in a hash
      def subscription_groups
        # We first build all the subscription groups, so they all get the same position, despite
        # later narrowing that. It allows us to maintain same position number for static members
        # even when we want to run subset of consumer groups or subscription groups
        #
        # We then narrow this to active consumer groups from which we select active subscription
        # groups.
        consumer_groups
          .map { |cg| [cg, cg.subscription_groups] }
          .select { |cg, _| cg.active? }
          .select { |_, sgs| sgs.delete_if { |sg| !sg.active? } }
          .delete_if { |_, sgs| sgs.empty? }
          .each { |_, sgs| sgs.each { |sg| sg.topics.delete_if { |top| !top.active? } } }
          .each { |_, sgs| sgs.delete_if { |sg| sg.topics.empty? } }
          .to_h
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
