# frozen_string_literal: true

# frozen_string_literal: true

module Karafka
  module Routing
    # Abstraction layer on top of groups of topics
    class Topics
      include Enumerable

      # @param topics_array [Array<Karafka::Routing::Topic>] array with topics
      def initialize(topics_array)
        @accumulator = topics_array.dup
      end

      # Adds topic to the topics group
      #
      # @param topic [Karafka::Routing::Topic]
      # @return [Karafka::Routing::Topic]
      def <<(topic)
        @accumulator << topic
      end

      # Yields each topic
      #
      # @param [Proc] block we want to yield with on each topic
      def each(&block)
        @accumulator.each(&block)
      end

      # @return [Boolean] is the group empty or not
      def empty?
        @accumulator.empty?
      end

      # @return [Karafka::Routing::Topic] last available topic
      def last
        @accumulator.last
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
