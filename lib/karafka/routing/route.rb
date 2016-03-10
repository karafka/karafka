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
      # Only ASCII alphanumeric characters and underscore and dash are allowed in topics and groups
      NAME_FORMAT = /\A(\w|\-)+\z/

      # Options that we can set per each route
      attr_writer :group, :topic, :worker, :parser, :interchanger

      # This we can get "directly" because it does not have any details, etc
      attr_accessor :controller

      # Initializes default values for all the options that support defaults if their values are
      # not yet specified. This is need to be done (cannot be lazy loaded on first use) because
      # everywhere except Karafka server command, those would not be initialized on time - for
      # example for Sidekiq
      def build
        group
        worker
        parser
        interchanger
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

      # @return [Class] Parser class (not instance) that we want to use to unparse Kafka messages
      # @note If not provided - will use JSON as default
      def parser
        @parser ||= JSON
      end

      # @return [Class] Interchanger class (not an instance) that we want to use to interchange
      #   params between Karafka server and Karafka background job
      def interchanger
        @interchanger ||= Karafka::Params::Interchanger
      end

      # Checks if topic and group have proper format (acceptable by Kafka)
      # @raise [Karafka::Errors::InvalidTopicName] raised when topic name is invalid
      # @raise [Karafka::Errors::InvalidGroupName] raised when group name is invalid
      def validate!
        raise Errors::InvalidTopicName, topic if (NAME_FORMAT =~ topic) != 0
        raise Errors::InvalidGroupName, group if (NAME_FORMAT =~ group) != 0
      end
    end
  end
end
