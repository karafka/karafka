# frozen_string_literal: true

module Karafka
  module Responders
    # Topic describes a single topic on which we want to respond with responding requirements
    # @example Define topic (required by default)
    #   Karafka::Responders::Topic.new(:topic_name, {}) #=> #<Karafka::Responders::Topic...
    # @example Define optional topic
    #   Karafka::Responders::Topic.new(:topic_name, required: false)
    class Topic
      # Name of the topic on which we want to respond
      attr_reader :name

      # @param name [Symbol, String] name of a topic on which we want to respond
      # @param options [Hash] non-default options for this topic
      # @return [Karafka::Responders::Topic] topic description object
      def initialize(name, options)
        @name = name.to_s
        @options = options
      end

      # @return [Boolean] is this a required topic (if not, it is optional)
      def required?
        @options.key?(:required) ? @options[:required] : true
      end

      # @return [Boolean] was usage of this topic registered or not
      def registered?
        @options[:registered] == true
      end

      # @return [Class] Class to use to serialize messages for this topic
      def serializer
        @options[:serializer]
      end

      # @return [Boolean] do we want to use async producer. Defaults to false as the sync producer
      #   is safer and introduces less problems
      def async?
        @options.key?(:async) ? @options[:async] : false
      end

      # @return [Hash] hash with this topic attributes and options
      def to_h
        {
          name: name,
          required: required?,
          registered: registered?,
          serializer: serializer,
          async: async?
        }
      end
    end
  end
end
