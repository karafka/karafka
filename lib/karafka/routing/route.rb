module Karafka
  module Routing
    # Class representing a single route (from topic to worker) with all additional features
    # and elements. Single route contains descriptions of:
    # - topic - Kafka topic name (required)
    # - controller - Class of a controller that will handle messages from a given topic (required)
    # - group - Kafka group that we want to use (optional)
    # - worker - Which worker should handle the backend task (optional)
    # - parser - What parsed do we want to use to unparse the data (optional)
    # - interchanger - What interchanger to encode/decode data do we want to use (optional)
    class Route
      # Only ASCII alphanumeric characters, underscore, dash and dots
      # are allowed in topics and groups
      NAME_FORMAT = /\A(\w|\-|\.)+\z/

      # Options that we can set per each route
      ATTRIBUTES = %i(
        group
        topic
        worker
        parser
        interchanger
        responder
        inline_mode
        batch_mode
      ).freeze

      ATTRIBUTES.each { |attr| attr_writer(attr) }

      # This we can get "directly" because it does not have any details, etc
      attr_accessor :controller

      # Initializes default values for all the options that support defaults if their values are
      # not yet specified. This is need to be done (cannot be lazy loaded on first use) because
      # everywhere except Karafka server command, those would not be initialized on time - for
      # example for Sidekiq
      def build
        ATTRIBUTES.each { |attr| send(attr) }
        self
      end

      # @return [String] Kafka group name
      # @note If group is not provided in a route, will build one based on the app name
      #   and the route topic (that is required)
      def group
        (@group ||= "#{Karafka::App.config.name.underscore}_#{topic}").to_s
      end

      # @return [String] route topic - this is the core esence of Kafka
      def topic
        @topic.to_s
      end

      # @return [Class] Class (not an instance) of a worker that should be used to schedule the
      #   background job
      # @note If not provided - will be built based on the provided controller
      def worker
        @worker ||= Karafka::Workers::Builder.new(controller).build
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

      # @return [Boolean] Should we perform execution in the background (default) or
      #   inline. This can be set globally and overwritten by a per route setting
      # @note This method can be set to false, so direct assigment ||= would not work
      def inline_mode
        return @inline_mode unless @inline_mode.nil?
        @inline_mode = Karafka::App.config.inline_mode
      end

      # @return [Boolean] Should the consumer handle incoming events one at a time, or in batch
      def batch_mode
        return @batch_mode unless @batch_mode.nil?
        @batch_mode = Karafka::App.config.batch_mode
      end

      # Checks if topic and group have proper format (acceptable by Kafka)
      # @raise [Karafka::Errors::InvalidTopicName] raised when topic name is invalid
      # @raise [Karafka::Errors::InvalidGroupName] raised when group name is invalid
      def validate!
        raise Errors::InvalidTopicName, topic if NAME_FORMAT !~ topic
        raise Errors::InvalidGroupName, group if NAME_FORMAT !~ group
      end
    end
  end
end
