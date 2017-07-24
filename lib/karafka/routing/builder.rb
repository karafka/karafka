# frozen_string_literal: true

module Karafka
  module Routing
    # Builder used as a DSL layer for building consumers and telling them which topics to consume
    # @example Build a simple (most common) route
    #   consumers do
    #     topic :new_videos do
    #       controller NewVideosController
    #     end
    #   end
    class Builder < Array
      include Singleton

      # Builds and saves given consumer group
      # @param group_id [String, Symbol] name for consumer group
      # @yield Evaluates a given block in a consumer group context
      def consumer_group(group_id, &block)
        self << ConsumerGroup.new(group_id.to_s, &block)
      end

      # @param topic_name [String, Symbol] name of a topic from which we want to consumer
      # @yield Evaluates a given block in a topic context
      def topic(topic_name, &block)
        self << ConsumerGroup.new(topic_name) do |consumer_group|
          topic(topic_name, &block).tap(&:build)
        end
      end

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
        freeze
      end
    end
  end
end
