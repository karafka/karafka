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
    class Builder < Array
      include Singleton

      # Used to draw routes for Karafka
      # @note After it is done drawing it will store and validate all the routes to make sure that
      #   they are correct and that there are no topic/group duplications (this is forbidden)
      # @yield Evaluates provided block in a builder context so we can describe routes
      # @example
      #   draw do
      #     topic :xyz do
      #     end
      #   end
      def draw(&block)
        instance_eval(&block)

        each do |consumer_group|
          hashed_group = consumer_group.to_h
          validation_result = Karafka::Schemas::ConsumerGroup.call(hashed_group)
          return if validation_result.success?
          raise Errors::InvalidConfiguration, validation_result.errors
        end
      end

      # @return [Array<Karafka::Routing::ConsumerGroup>] only active consumer groups that
      #   we want to use. Since Karafka supports multi-process setup, we need to be able
      #   to pick only those consumer groups that should be active in our given process context
      def active
        select(&:active?)
      end

      private

      # Builds and saves given consumer group
      # @param group_id [String, Symbol] name for consumer group
      # @yield Evaluates a given block in a consumer group context
      def consumer_group(group_id, &block)
        consumer_group = ConsumerGroup.new(group_id.to_s)
        self << Proxy.new(consumer_group, &block).target
      end

      # @param topic_name [String, Symbol] name of a topic from which we want to consumer
      # @yield Evaluates a given block in a topic context
      def topic(topic_name, &block)
        consumer_group(topic_name) do
          topic(topic_name, &block).tap(&:build)
        end
      end
    end
  end
end
