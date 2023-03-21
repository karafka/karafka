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

      def initialize
        # We load them once for performance reasons not to do too many lookups
        @strategies = find_all
      end

      # @param topic [Karafka::Routing::Topic] topic with settings based on which we find strategy
      # @return [Module] module with proper strategy
      def find(topic)
        feature_set = SUPPORTED_FEATURES.map do |feature_name|
          topic.public_send("#{feature_name}?") ? feature_name : nil
        end

        feature_set.compact!

        @strategies.find do |strategy|
          strategy::FEATURES.sort == feature_set.sort
        end || raise(Errors::StrategyNotFoundError, topic.name)
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
