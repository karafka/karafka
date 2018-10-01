# frozen_string_literal: true

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
  # @example Responding to a topic with extra options
  #   class Responder < BaseResponder
  #     topic :new_action
  #
  #     def respond(data)
  #       respond_to :new_action, data, partition_key: 'thing'
  #     end
  #   end
  #
  # @example Marking topic as not required (we won't have to use it)
  #   class Responder < BaseResponder
  #     topic :required_topic
  #     topic :new_action, required: false
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
  #
  # @example Accept multiple arguments to a respond method
  #   class Responder < BaseResponder
  #     topic :users_actions
  #     topic :articles_viewed
  #
  #     def respond(user, article)
  #       respond_to :users_actions, user
  #       respond_to :articles_viewed, article
  #     end
  #   end
  class BaseResponder
    # Definitions of all topics that we want to be able to use in this responder should go here
    class_attribute :topics

    # Schema that we can use to control and/or require some additional details upon options
    # that are being passed to the producer. This can be in particular useful if we want to make
    # sure that for example partition_key is always present.
    class_attribute :options_schema

    attr_reader :messages_buffer

    class << self
      # Registers a topic as on to which we will be able to respond
      # @param topic_name [Symbol, String] name of topic to which we want to respond
      # @param options [Hash] hash with optional configuration details
      def topic(topic_name, options = {})
        self.topics ||= {}
        topic_obj = Responders::Topic.new(topic_name, options.merge(registered: true))
        self.topics[topic_obj.name] = topic_obj
      end

      # A simple alias for easier standalone responder usage.
      # Instead of building it with new.call it allows (in case of usin JSON parser)
      # to just run it directly from the class level
      # @param data Anything that we want to respond with
      # @example Send user data with a responder (uses default Karafka::Parsers::Json parser)
      #   UsersCreatedResponder.call(@created_user)
      def call(*data)
        # Just in case there were no topics defined for a responder, we initialize with
        # empty hash not to handle a nil case
        self.topics ||= {}
        new.call(*data)
      end
    end

    # Creates a responder object
    # @param parser_class [Class] parser class that we can use to generate appropriate string
    #   or nothing if we want to default to Karafka::Parsers::Json
    # @return [Karafka::BaseResponder] base responder descendant responder
    def initialize(parser_class = Karafka::App.config.parser)
      @parser_class = parser_class
      @messages_buffer = {}
    end

    # Performs respond and validates that all the response requirement were met
    # @param data Anything that we want to respond with
    # @note We know that validators should be executed also before sending data to topics, however
    #   the implementation gets way more complicated then, that's why we check after everything
    #   was sent using responder
    # @example Send user data with a responder (uses default Karafka::Parsers::Json parser)
    #   UsersCreatedResponder.new.call(@created_user)
    # @example Send user data with a responder using non default Parser
    #   UsersCreatedResponder.new(MyParser).call(@created_user)
    def call(*data)
      respond(*data)
      validate_usage!
      validate_options!
      deliver!
    end

    private

    # Checks if we met all the topics requirements. It will fail if we didn't send a message to
    # a registered required topic, etc.
    def validate_usage!
      registered_topics = self.class.topics.map do |name, topic|
        topic.to_h.merge!(
          usage_count: messages_buffer[name]&.count || 0
        )
      end

      used_topics = messages_buffer.map do |name, usage|
        topic = self.class.topics[name] || Responders::Topic.new(name, registered: false)
        topic.to_h.merge!(usage_count: usage.count)
      end

      result = Karafka::Schemas::ResponderUsage.call(
        registered_topics: registered_topics,
        used_topics: used_topics
      )

      return if result.success?

      raise Karafka::Errors::InvalidResponderUsage, result.errors
    end

    # Checks if we met all the options requirements before sending them to the producer.
    def validate_options!
      return true unless self.class.options_schema

      messages_buffer.each_value do |messages_set|
        messages_set.each do |message_data|
          result = self.class.options_schema.call(message_data.last)
          next if result.success?
          raise Karafka::Errors::InvalidResponderMessageOptions, result.errors
        end
      end
    end

    # Takes all the messages from the buffer and delivers them one by one
    # @note This method is executed after the validation, so we're sure that
    #   what we send is legit and it will go to a proper topics
    def deliver!
      messages_buffer.each_value do |data_elements|
        data_elements.each do |data, options|
          # We map this topic name, so it will match namespaced/etc topic in Kafka
          # @note By default will not change topic (if default mapper used)
          mapped_topic = Karafka::App.config.topic_mapper.outgoing(options[:topic])
          external_options = options.merge(topic: mapped_topic)
          producer(options).call(data, external_options)
        end
      end
    end

    # Method that needs to be implemented in a subclass. It should handle responding
    #   on registered topics
    # @raise [NotImplementedError] This method needs to be implemented in a subclass
    def respond(*_data)
      raise NotImplementedError, 'Implement this in a subclass'
    end

    # This method allow us to respond to a single topic with a given data. It can be used
    # as many times as we need. Especially when we have 1:n flow
    # @param topic [Symbol, String] topic to which we want to respond
    # @param data [String, Object] string or object that we want to send
    # @param options [Hash] options for waterdrop (e.g. partition_key)
    # @note Respond to does not accept multiple data arguments.
    def respond_to(topic, data, options = {})
      # We normalize the format to string, as WaterDrop and Ruby-Kafka support only
      # string topics
      topic = topic.to_s

      messages_buffer[topic] ||= []
      messages_buffer[topic] << [
        @parser_class.generate(data),
        options.merge(topic: topic)
      ]
    end

    # @param options [Hash] options for waterdrop
    # @return [Class] WaterDrop producer (sync or async based on the settings)
    def producer(options)
      self.class.topics[
        options[:topic]
      ].async? ? WaterDrop::AsyncProducer : WaterDrop::SyncProducer
    end
  end
end
