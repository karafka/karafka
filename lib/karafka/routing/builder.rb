# frozen_string_literal: true

module Karafka
  module Routing
    # Builder used as a DSL layer for building consumers and telling them which topics to consume
    # @example Build a simple (most common) route
    #   consumers do
    #     topic :new_videos do
    #       consumer NewVideosConsumer
    #     end
    #   end
    class Builder < Concurrent::Array
      # Consumer group consistency checking contract
      CONTRACT = Karafka::Contracts::ConsumerGroup.new.freeze

      private_constant :CONTRACT

      def initialize
        @draws = Concurrent::Array.new
      end

      # Used to draw routes for Karafka
      # @note After it is done drawing it will store and validate all the routes to make sure that
      #   they are correct and that there are no topic/group duplications (this is forbidden)
      # @param block [Proc] block we will evaluate within the builder context
      # @yield Evaluates provided block in a builder context so we can describe routes
      # @raise [Karafka::Errors::InvalidConfigurationError] raised when configuration
      #   doesn't match with the config contract
      # @example
      #   draw do
      #     topic :xyz do
      #     end
      #   end
      def draw(&block)
        @draws << block

        instance_eval(&block)

        each do |consumer_group|
          hashed_group = consumer_group.to_h
          validation_result = CONTRACT.call(hashed_group)
          next if validation_result.success?

          raise Errors::InvalidConfigurationError, validation_result.errors.to_h
        end
      end

      # @return [Array<Karafka::Routing::ConsumerGroup>] only active consumer groups that
      #   we want to use. Since Karafka supports multi-process setup, we need to be able
      #   to pick only those consumer groups that should be active in our given process context
      def active
        select(&:active?)
      end

      # Clears the builder and the draws memory
      def clear
        @draws.clear
        super
      end

      # Redraws all the routes for the in-process code reloading.
      # @note This won't allow registration of new topics without process restart but will trigger
      #   cache invalidation so all the classes, etc are re-fetched after code reload
      def reload
        draws = @draws.dup
        clear
        draws.each { |block| draw(&block) }
      end

      private

      # Builds and saves given consumer group
      # @param group_id [String, Symbol] name for consumer group
      # @param block [Proc] proc that should be executed in the proxy context
      def consumer_group(group_id, &block)
        consumer_group = ConsumerGroup.new(group_id.to_s)
        self << Proxy.new(consumer_group, &block).target
      end

      # @param topic_name [String, Symbol] name of a topic from which we want to consumer
      # @param block [Proc] proc we want to evaluate in the topic context
      def topic(topic_name, &block)
        consumer_group(topic_name) do
          topic(topic_name, &block).tap(&:build)
        end
      end
    end
  end
end
