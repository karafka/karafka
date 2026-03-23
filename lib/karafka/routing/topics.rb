# frozen_string_literal: true

module Karafka
  module Routing
    # Abstraction layer on top of groups of topics
    class Topics
      include Enumerable
      extend Forwardable

      def_delegators :@accumulator, :[], :size, :empty?, :last

      # @param topics_array [Array<Karafka::Routing::Topic>] array with topics
      def initialize(topics_array)
        @accumulator = topics_array.dup
        @index = nil
      end

      # Yields each topic
      def each(&)
        @accumulator.each(&)
      end

      # Appends a topic and invalidates the lookup index
      def <<(topic)
        @index = nil
        @accumulator << topic
      end

      # Allows us to remove elements from the topics
      #
      # Block to decide what to delete
      def delete_if(&)
        @index = nil
        @accumulator.delete_if(&)
      end

      # @see Array#map!
      def map!(&)
        @index = nil
        @accumulator.map!(&)
      end

      # @see Array#sort_by!
      def sort_by!(&)
        @index = nil
        @accumulator.sort_by!(&)
      end

      # @see Array#reverse!
      def reverse!
        @index = nil
        @accumulator.reverse!
      end

      # Finds topic by its name
      #
      # @param topic_name [String] topic name
      # @return [Karafka::Routing::Topic]
      # @raise [Karafka::Errors::TopicNotFoundError] this should never happen. If you see it,
      #   please create an issue.
      def find(topic_name)
        index[topic_name] || raise(Karafka::Errors::TopicNotFoundError, topic_name)
      end

      private

      # Builds or returns a cached name-to-topic hash index for O(1) lookups
      # @return [Hash<String, Karafka::Routing::Topic>]
      def index
        @index ||= @accumulator.each_with_object({}) { |topic, h| h[topic.name] = topic }
      end
    end
  end
end
