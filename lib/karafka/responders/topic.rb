module Karafka
  module Responders
    # Topic describes a single topic on which we want to respond with responding requirements
    # @example Define topic (required by default)
    #   Karafka::Responders::Topic.new(:topic_name, {}) #=> #<Karafka::Responders::Topic...
    # @example Define optional topic
    #   Karafka::Responders::Topic.new(:topic_name, optional: true)
    # @example Define topic that on which we want to respond multiple times
    #   Karafka::Responders::Topic.new(:topic_name, multiple_usage: true)
    class Topic
      # Name of the topic on which we want to respond
      attr_reader :name

      # @param name [Symbol, String] name of a topic on which we want to respond
      # @param options [Hash] non-default options for this topic
      # @return [Karafka::Responders::Topic] topic description object
      def initialize(name, options)
        @name = name.to_s
        @options = options
        validate!
      end

      # @return [Boolean] is this a required topic (if not, it is optional)
      def required?
        return false if @options[:optional]
        @options[:required] || true
      end

      # @return [Boolean] do we expect to use it multiple times in a single respond flow
      def multiple_usage?
        @options[:multiple_usage] || false
      end

      private

      # Checks topic name with the same regexp as routing
      # @raise [Karafka::Errors::InvalidTopicName] raised when topic name is invalid
      def validate!
        raise Errors::InvalidTopicName, name if Routing::Route::NAME_FORMAT !~ name
      end
    end
  end
end
