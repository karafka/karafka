# frozen_string_literal: true

module Karafka
  module Routing
    # Builder used as a DSL layer for building consumers and telling them which topics to consume
    #
    # @note We lock the access just in case this is used in patterns. The locks here do not have
    #   any impact on routing usage unless being expanded, so no race conditions risks.
    #
    # @example Build a simple (most common) route
    #   consumers do
    #     topic :new_videos do
    #       consumer NewVideosConsumer
    #     end
    #   end
    class Builder < Array
      include Helpers::ConfigImporter.new(
        default_group_id: %i[group_id]
      )

      # Empty default per-topic config
      EMPTY_DEFAULTS = ->(_) {}.freeze

      private_constant :EMPTY_DEFAULTS

      def initialize
        @mutex = Mutex.new
        @draws = []
        @defaults = EMPTY_DEFAULTS
        super
      end

      # Used to draw routes for Karafka
      # @param block [Proc] block we will evaluate within the builder context
      # @yield Evaluates provided block in a builder context so we can describe routes
      # @raise [Karafka::Errors::InvalidConfigurationError] raised when configuration
      #   doesn't match with the config contract
      # @note After it is done drawing it will store and validate all the routes to make sure that
      #   they are correct and that there are no topic/group duplications (this is forbidden)
      # @example
      #   draw do
      #     topic :xyz do
      #     end
      #   end
      def draw(&block)
        @mutex.synchronize do
          @draws << block

          instance_eval(&block)

          # Ensures high-level routing details consistency
          # Contains checks that require knowledge about all the consumer groups to operate
          Contracts::Routing.new.validate!(map(&:to_h))

          each do |consumer_group|
            # Validate consumer group settings
            Contracts::ConsumerGroup.new.validate!(consumer_group.to_h)

            # and then its topics settings
            consumer_group.topics.each do |topic|
              Contracts::Topic.new.validate!(topic.to_h)
            end

            # Initialize subscription groups after all the routing is done
            consumer_group.subscription_groups
          end
        end
      end

      # Clear out the drawn routes.
      alias array_clear clear
      private :array_clear

      # Clear routes and draw them again with the given block. Helpful for testing purposes.
      # @param block [Proc] block we will evaluate within the builder context
      def redraw(&block)
        @mutex.synchronize do
          @draws.clear
          array_clear
        end
        draw(&block)
      end

      # @return [Array<Karafka::Routing::ConsumerGroup>] only active consumer groups that
      #   we want to use. Since Karafka supports multi-process setup, we need to be able
      #   to pick only those consumer groups that should be active in our given process context
      def active
        select(&:active?)
      end

      # Clears the builder and the draws memory
      def clear
        @mutex.synchronize do
          @defaults = EMPTY_DEFAULTS
          @draws.clear
          array_clear
        end
      end

      # @param block [Proc] block with per-topic evaluated defaults
      # @return [Proc] defaults that should be evaluated per topic
      def defaults(&block)
        return @defaults unless block

        if @mutex.owned?
          @defaults = block
        else
          @mutex.synchronize do
            @defaults = block
          end
        end
      end

      private

      # Builds and saves given consumer group
      # @param group_id [String, Symbol] name for consumer group
      # @param block [Proc] proc that should be executed in the proxy context
      def consumer_group(group_id, &block)
        consumer_group = find { |cg| cg.name == group_id.to_s }

        if consumer_group
          Proxy.new(consumer_group, &block).target
        else
          consumer_group = ConsumerGroup.new(group_id.to_s)
          self << Proxy.new(consumer_group, &block).target
        end
      end

      # Handles the simple routing case where we create one consumer group and allow for further
      # subscription group customization
      # @param subscription_group_name [String, Symbol] subscription group id. When not provided,
      #   a random uuid will be used
      # @param args [Array] any extra arguments accepted by the subscription group builder
      # @param block [Proc] further topics definitions
      def subscription_group(
        subscription_group_name = SubscriptionGroup.id,
        **args,
        &block
      )
        consumer_group(default_group_id) do
          target.public_send(
            :subscription_group=,
            subscription_group_name.to_s,
            **args,
            &block
          )
        end
      end

      # In case we use simple style of routing, all topics will be assigned to the same consumer
      # group that will be based on the client_id
      #
      # @param topic_name [String, Symbol] name of a topic from which we want to consumer
      # @param block [Proc] proc we want to evaluate in the topic context
      def topic(topic_name, &block)
        consumer_group(default_group_id) do
          topic(topic_name, &block)
        end
      end
    end
  end
end
