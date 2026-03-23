# frozen_string_literal: true

module Karafka
  module Processing
    # Selector of appropriate processing strategy matching topic combinations
    class StrategySelector
      attr_reader :strategies

      # Features we support in the OSS offering.
      SUPPORTED_FEATURES = %i[
        active_job
        manual_offset_management
        dead_letter_queue
      ].freeze

      # Initializes the strategy selector and preloads all strategies
      def initialize
        # We load them once for performance reasons not to do too many lookups
        @strategies = find_all
        # Pre-build an index of sorted features to strategy for O(1) lookup
        @strategies_index = @strategies.each_with_object({}) do |strategy, h|
          h[strategy::FEATURES.sort] = strategy
        end
      end

      # @param topic [Karafka::Routing::Topic] topic with settings based on which we find strategy
      # @return [Module] module with proper strategy
      def find(topic)
        feature_set = SUPPORTED_FEATURES.each_with_object([]) do |feature_name, acc|
          acc << feature_name if topic.public_send("#{feature_name}?")
        end

        feature_set.sort!

        @strategies_index[feature_set] ||
          raise(Errors::StrategyNotFoundError, topic.name)
      end

      private

      # @return [Array<Module>] available strategies
      def find_all
        Strategies
          .constants
          .delete_if { |k| k == :Base }
          .map { |k| Strategies.const_get(k) }
          .uniq
      end
    end
  end
end
