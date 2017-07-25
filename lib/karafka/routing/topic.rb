# frozen_string_literal: true

module Karafka
  module Routing
    # Topic stores all the details on how we should interact with Kafka given topic
    # It belongs to a consumer group as from 0.6 all the topics can work in the same consumer group
    # It is a part of Karafka's DSL
    class Topic
      extend Helpers::ConfigRetriever

      # @param [String, Symbol] name of a topic on which we want to listen
      # @param consumer_group [Karafka::Routing::ConsumerGroup] owning consumer group of this topic
      def initialize(name, consumer_group)
        @name = name
        @consumer_group = consumer_group
        @attributes = {}
      end

      attr_reader :consumer_group

      # @return [String] unique topic identifier
      # @note We use identifier related to the consumer group that owns a topic, because from
      #   Karafka 0.6 we can handle multiple Kafka instances with the same process and we can have
      #   same topic name across mutliple Kafkas
      def id
        "#{consumer_group.id}_#{@name}"
      end

      # Initializes default values for all the options that support defaults if their values are
      # not yet specified. This is need to be done (cannot be lazy loaded on first use) because
      # everywhere except Karafka server command, those would not be initialized on time - for
      # example for Sidekiq
      def build
        Karafka::AttributesMap.topic_attributes.each { |attr| send(attr) }
        self
      end

      # @return [Class] Class (not an instance) of a worker that should be used to schedule the
      #   background job
      # @note If not provided - will be built based on the provided controller
      def worker
        @worker ||= inline_mode ? nil : Karafka::Workers::Builder.new(controller).build
      end

      # @return [Class, nil] Class (not an instance) of a responder that should respond from
      #   controller back to Kafka (usefull for piping dataflows)
      def responder
        @responder ||= Karafka::Responders::Builder.new(controller).build
      end

      # @return [Class] Parser class (not instance) that we want to use to unparse Kafka messages
      # @note If not provided - will use Json as default
      def parser
        @parser ||= Karafka::Parsers::Json
      end

      # @return [Class] Interchanger class (not an instance) that we want to use to interchange
      #   params between Karafka server and Karafka background job
      def interchanger
        @interchanger ||= Karafka::Params::Interchanger
      end

      Karafka::AttributesMap.topic_attributes.each do |attribute|
        config_retriever_for(attribute)
      end

      def to_h
        result = {
          worker: worker,
          id: id,
          controller: controller,
          responder: responder,
          parser: parser,
          interchanger: interchanger
        }

        Karafka::AttributesMap.topic_attributes.each do |attribute|
          result[attribute] = public_send(attribute)
        end

        result
      end
    end
  end
end
