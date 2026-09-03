# frozen_string_literal: true

module Karafka
  module Routing
    module Groups
      # Object used to describe a single consumer group that is going to subscribe to given topics.
      #
      # This is the canonical consumer group class. It is also reachable via the legacy flat
      # {Karafka::Routing::ConsumerGroup} alias, which is kept for backwards compatibility and is
      # scheduled for retirement in Karafka 3.0.
      class ConsumerGroup < Base
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
          Topics::ConsumerGroupTopic
        end
      end
    end
  end
end
