# frozen_string_literal: true

module Karafka
  module Routing
    # Aggregator for topics, that gives us additional #active scope for selecting only
    # active topics in our current process context
    # @note This does not need to be concurrently save, as we don't modify that during the runtime
    class TopicGroup < Array
      # @return [Array<Karafka::Routing::Topic>] array with active topics
      def active
        select(&:active?)
      end
    end
  end
end
