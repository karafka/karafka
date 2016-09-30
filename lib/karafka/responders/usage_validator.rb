module Karafka
  module Responders
    # Usage validator checks if all the requirements related to responders topics were met
    class UsageValidator
      # @param registered_topics [Hash] Hash with registered topics objects from
      #   a given responder class under it's name key
      # @param used_topics [Array<String>] Array with names of topics that we used in this
      #   responding process
      # @return [Karafka::Responders::UsageValidator] responding flow usage validator
      def initialize(registered_topics, used_topics)
        @registered_topics = registered_topics
        @used_topics = used_topics
      end

      # Validates the whole flow
      # @raise [Karafka::Errors::UnregisteredTopic] raised when we used a topic that we didn't
      #   register using #topic method
      # @raise [Karafka::Errors::TopicMultipleUsage] raised when we used a non multipleusage topic
      #   multiple times
      # @raise [Karafka::Errors::UnusedResponderRequiredTopic] raised when we didn't use a topic
      #   that was defined as required to be used
      def validate!
        @used_topics.each do |used_topic|
          validate_usage_of!(used_topic)
        end

        @registered_topics.each do |_name, registered_topic|
          validate_requirements_of!(registered_topic)
        end
      end

      private

      # Checks if a given used topic were used in a proper way
      # @raise [Karafka::Errors::UnregisteredTopic] raised when we used a topic that we didn't
      #   register using #topic method
      # @raise [Karafka::Errors::TopicMultipleUsage] raised when we used a non multipleusage topic
      #   multiple times
      # @param used_topic [String] topic to which we've sent a message
      def validate_usage_of!(used_topic)
        raise(Errors::UnregisteredTopic, used_topic) unless @registered_topics[used_topic]
        return if @registered_topics[used_topic].multiple_usage?
        return if @used_topics.count(used_topic) < 2
        raise(Errors::TopicMultipleUsage, used_topic)
      end

      # Checks if we met all the requirements for all the registered topics
      # @raise [Karafka::Errors::UnusedResponderRequiredTopic] raised when we didn't use a topic
      #   that was defined as required to be used
      # @param registered_topic [::Karafka::Responders::Topic] registered topic object
      def validate_requirements_of!(registered_topic)
        return unless registered_topic.required?
        return if @used_topics.include?(registered_topic.name)

        raise(Errors::UnusedResponderRequiredTopic, registered_topic.name)
      end
    end
  end
end
