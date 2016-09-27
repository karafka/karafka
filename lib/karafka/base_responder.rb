module Karafka
  # Base responder from which all Karafka responders should inherit
  # Similar to Rails responders concept. It allows us to design flow from one app to another
  # by isolating what responses should be sent (and where) based on a given action
  # It differs from Rails responders in the way it works: in std http request we can have one
  # response, here we can have unlimited number of them
  #
  # It has a simple API for defining where should we respond (and if it is required)
  #
  # @example Basic usage (each registered topic is required to be used by default)
  #   class Responder < BaseResponder
  #     topic :new_action
  #
  #     def respond(data)
  #       respond_to :new_action, data
  #     end
  #   end
  #
  # @example Marking topic as optional (we won't have to use it)
  #   class Responder < BaseResponder
  #     topic :required_topic
  #     topic :new_action, optional: true
  #
  #     def respond(data)
  #       respond_to :required_topic, data
  #     end
  #   end
  #
  # @example Multiple times used topic
  #   class Responder < BaseResponder
  #     topic :required_topic, multiple_usage: true
  #
  #     def respond(data)
  #       data.each do |subset|
  #         respond_to :required_topic, subset
  #       end
  #     end
  #   end
  class BaseResponder
    # Definitions of all topics that we want to be able to use in this responder should go here
    class_attribute :topics

    class << self
      # Registers a topic as on to which we will be able to respond
      # @param topic_name [Symbol, String] name of topic to which we want to respond
      # @param options [Hash] hash with optional configuration details
      def topic(topic_name, options = {})
        self.topics ||= {}
        topic_obj = Responders::Topic.new(topic_name, options)
        self.topics[topic_obj.name] = topic_obj
      end
    end

    # Creates a responder object
    # @return [Karafka::BaseResponder] base responder descendant responder
    def initialize
      @used_topics = []
    end

    # Performs respond and validates that all the response requirement were met
    def call(data)
      respond(data)
      validate!
    end

    private

    # This method allow us to respond to a single topic with a given data. It can be used
    # as many times as we need. Especially when we have 1:n flow
    # @param topic [Symbol, String] topic to which we want to respond
    # @param data [String, Object] string or object that we want to send
    # @note Note that if we pass object here (not a string), this method will invoke a #to_json
    #   on it.
    def respond_to(topic, data)
      topic = topic.to_s
      @used_topics << topic

      data = data.to_json unless data.is_a?(String)
      ::WaterDrop::Message.new(topic, data).send!
    end

    # Checks if we met all the topics requirements. It will fail if we didn't send a message to
    # a registered required topic, etc.
    def validate!
      Responders::UsageValidator.new(
        self.class.topics || {},
        @used_topics
      ).validate!
    end
  end
end
