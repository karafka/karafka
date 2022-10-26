# frozen_string_literal: true

module Karafka
  module Processing
    # Selector of appropriate processing strategy matching topic combinations
    class StrategySelector
      def initialize
        # We load them once for performance reasons not to do too many lookups
        @available_strategies = Strategies
                                .constants
                                .delete_if { |k| k == :Base }
                                .map { |k| Strategies.const_get(k) }
      end

      # @param topic [Karafka::Routing::Topic] topic with settings based on which we find strategy
      # @return [Module] module with proper strategy
      def find(topic)
        # ActiveJob usage is not a feature that would impact the strategy. ActiveJob always goes
        # with manual offset management.
        feature_set = [
          topic.manual_offset_management? ? :manual_offset_management : nil
        ].compact

        @available_strategies.find do |strategy|
          strategy::FEATURES.sort == feature_set.sort
        end || raise(Errors::StrategyNotFoundError, topic.name)
      end
    end
  end
end
