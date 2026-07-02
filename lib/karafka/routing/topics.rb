# frozen_string_literal: true

module Karafka
  module Routing
    # Abstraction layer on top of groups of topics
    class Topics
      include Enumerable
      extend Forwardable

      def_delegators :@accumulator, :[], :size, :empty?, :last, :map!, :sort_by!, :reverse!

      # @param topics_array [Array<Karafka::Routing::Topic>] array with topics
      def initialize(topics_array)
        @accumulator = topics_array.dup
      end

      # Adds a topic using copy-on-write: we publish a brand-new accumulator array instead of
      # mutating the existing one in place.
      #
      # @param topic [Karafka::Routing::Topic] topic that should become part of this consumer
      #   group's topics
      # @return [self]
      #
      # @note Topics can be appended to this collection at runtime from one thread while other
      #   threads iterate the same collection (for example during routing lookups). Swapping the
      #   `@accumulator` reference atomically (rather than appending in place) guarantees a
      #   concurrent `#each` always traverses a complete, immutable snapshot: it either sees the
      #   newly added topic or it does not, but never a torn array. This holds on every Ruby
      #   runtime, not only on MRI's GIL. The in-place mutators above (`map!`, `sort_by!`,
      #   `reverse!`) only run while routes are built at boot, single-threaded, so they do not
      #   need the same treatment.
      def <<(topic)
        @accumulator += [topic]
        self
      end

      # Yields each topic
      def each(&)
        @accumulator.each(&)
      end

      # Allows us to remove elements from the topics
      #
      # Block to decide what to delete
      def delete_if(&)
        @accumulator.delete_if(&)
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
