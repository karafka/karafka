# frozen_string_literal: true

module Karafka
  module Routing
    # Object used to describe a single consumer group that is going to subscribe to
    # given topics.
    #
    # @note This is the canonical consumer-group class. It is also reachable as
    #   {Karafka::Routing::Groups::ConsumerGroup}. Both point at the same class - the flat
    #   `Routing::ConsumerGroup` constant is kept because it is widely referenced and is de-facto
    #   public API.
    class ConsumerGroup < Groups::Base
      # @return [Symbol] group type
      def group_type
        :consumer
      end

      private

      # @return [Symbol] activity-manager scope consumer groups filter under
      def activity_scope
        :consumer_groups
      end

      # @return [Class] topic class used for consumer-group topics (the one CG routing features
      #   attach to)
      def topic_class
        Topic
      end
    end
  end
end
