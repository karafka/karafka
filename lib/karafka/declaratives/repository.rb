# frozen_string_literal: true

module Karafka
  module Declaratives
    # Holds all topic declarations. Single source of truth for "what topics have been declared."
    # Both the new DSL and the routing bridge populate this repository.
    class Repository
      def initialize
        @topics = {}
      end

      # Finds an existing declaration or creates a new one for the given topic name
      # @param name [String, Symbol] topic name
      # @return [Karafka::Declaratives::Topic] the declaration
      def find_or_create(name)
        @topics[name.to_s] ||= Topic.new(name)
      end

      # @return [Array<Karafka::Declaratives::Topic>] all declarations where active? is true
      def active
        @topics.values.select(&:active?)
      end

      # @param name [String, Symbol] topic name
      # @return [Karafka::Declaratives::Topic, nil] the declaration or nil
      def find(name)
        @topics[name.to_s]
      end

      # Iterates over all declarations
      # @param block [Proc] block to yield each topic to
      def each(&block)
        @topics.each_value(&block)
      end

      # @return [Integer] number of declarations
      def size
        @topics.size
      end

      # @return [Boolean] are there any declarations
      def empty?
        @topics.empty?
      end

      # Removes all declarations
      def clear
        @topics.clear
      end
    end
  end
end
