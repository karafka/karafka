# frozen_string_literal: true

module Karafka
  module Routing
    # Topic stores all the details on how we should interact with Kafka given topic
    # It belongs to a consumer group as from 0.6 all the topics can work in the same consumer group
    # It is a part of Karafka's DSL
    class Topic
      extend Helpers::ConfigRetriever

      attr_reader :id, :consumer_group
      attr_accessor :controller

      # @param [String, Symbol] name of a topic on which we want to listen
      # @param consumer_group [Karafka::Routing::ConsumerGroup] owning consumer group of this topic
      def initialize(name, consumer_group)
        @name = name.to_s
        @consumer_group = consumer_group
        @attributes = {}
        # @note We use identifier related to the consumer group that owns a topic, because from
        #   Karafka 0.6 we can handle multiple Kafka instances with the same process and we can
        #   have same topic name across mutliple Kafkas
        @id = "#{consumer_group.id}_#{@name}"
      end

      # Initializes default values for all the options that support defaults if their values are
      # not yet specified. This is need to be done (cannot be lazy loaded on first use) because
      # everywhere except Karafka server command, those would not be initialized on time - for
      # example for Sidekiq
      def build
        Karafka::AttributesMap.topic.each { |attr| send(attr) }
        controller&.topic = self
        self
      end

      # @return [Class] Class (not an instance) of a worker that should be used to schedule the
      #   background job
      # @note If not provided - will be built based on the provided controller
      def worker
        @worker ||= backend == :sidekiq ? Workers::Builder.new(controller).build : nil
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

      Karafka::AttributesMap.topic.each do |attribute|
        config_retriever_for(attribute)
      end

      # @return [Hash] hash with all the topic attributes
      # @note This is being used when we validate the consumer_group and its topics
      def to_h
        map = Karafka::AttributesMap.topic.map do |attribute|
          [attribute, public_send(attribute)]
        end

        Hash[map].merge!(
          id: id,
          controller: controller
        )
      end
    end
  end
end
