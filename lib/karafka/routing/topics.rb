# frozen_string_literal: true

# frozen_string_literal: true

module Karafka
  module Routing
    # Abstraction layer on top of groups of topics
    class Topics
      include Enumerable
      extend Forwardable

      def_delegators :@accumulator, :[], :size, :empty?, :last, :<<, :map!, :sort_by!, :reverse!

      # @param topics_array [Array<Karafka::Routing::Topic>] array with topics
      def initialize(topics_array)
        @accumulator = topics_array.dup
      end

      # Yields each topic
      #
      # @param [Proc] block we want to yield with on each topic
      def each(&block)
        @accumulator.each(&block)
      end

      # Allows us to remove elements from the topics
      #
      # Block to decide what to delete
      # @param block [Proc]
      def delete_if(&block)
        @accumulator.delete_if(&block)
      end

      # Finds topic by its name
      #
      # @param topic_name [String] topic name
      # @return [Karafka::Routing::Topic]
      # @raise [Karafka::Errors::TopicNotFoundError] this should never happen. If you see it,
      #   please create an issue.
      def find(topic_name)
        @accumulator.find { |topic| topic.name == topic_name } ||
          raise(Karafka::Errors::TopicNotFoundError, topic_name)
      end
    end
  end
end
