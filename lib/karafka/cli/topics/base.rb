# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Base class for all the topics related operations
      class Base
        include Helpers::Colorize
        include Helpers::ConfigImporter.new(
          kafka_config: %i[kafka]
        )

        private

        # Used to run Karafka Admin commands that talk with Kafka and that can fail due to broker
        # errors and other issues. We catch errors and provide nicer printed output prior to
        # re-raising the mapped error for proper exit code status handling
        #
        # @param operation_message [String] message that we use to print that it is going to run
        #   and if case if failed with a failure indication.
        def supervised(operation_message)
          puts "#{operation_message}..."

          yield
        rescue Rdkafka::RdkafkaError => e
          raise_failed(operation_message, e)
        end

        # Prints a failed operation with its error and raises the mapped error for proper exit
        # code status handling
        #
        # @param operation_message [String] message of the operation that failed
        # @param error [Rdkafka::RdkafkaError] error that failed it
        # @raise [Karafka::Errors::CommandValidationError] always
        def raise_failed(operation_message, error)
          puts "#{operation_message} #{red("failed")}:"
          puts error

          raise Errors::CommandValidationError, cause: error
        end

        # @return [Array<Karafka::Declaratives::Topic>] all available topics that can be managed
        # @note Topics with bootstrap servers that differ from the default kafka config are
        #   considered to belong to a different cluster and are excluded.
        def declaratives_routing_topics
          @declaratives_routing_topics ||= begin
            default_servers = kafka_config[:"bootstrap.servers"]

            App.declaratives.topics.reject do |topic|
              # Topics with explicit bootstrap servers that differ from the default are on a
              # different cluster. Topics without bootstrap_servers set (e.g. from the standalone
              # DSL) are assumed to belong to the default cluster.
              topic.bootstrap_servers && topic.bootstrap_servers != default_servers
            end
          end
        end

        # Fails when any declarative topic has configuration that the cluster does not know. Such
        # configuration would never be applied, so we stop before changing anything.
        #
        # @raise [Karafka::Errors::CommandValidationError] when unknown configuration is present
        def ensure_configs_exist_in_cluster!
          return if unknown_configs.empty?

          unknown_configs.each do |topic, configs|
            puts "#{red("Failed")} because topic #{topic.name} has configuration unknown to " \
              "the cluster: #{configs.keys.join(", ")}."
          end

          raise Errors::CommandValidationError
        end

        # @return [Hash{Karafka::Declaratives::Topic => Hash{String => String}}] declarative
        #   topics with their configs (names with values) that the cluster does not know and so
        #   could never be applied
        def unknown_configs
          @unknown_configs ||= find_unknown_configs
        end

        # @param as_new [Boolean] checks every topic as one to be created
        # @return [Hash{Karafka::Declaratives::Topic => Hash{String => String}}] declarative
        #   topics with their configs that the cluster does not know
        # @raise [Karafka::Errors::CommandValidationError] when we could not read the topics
        #   configuration from the cluster (e.g. not allowed to describe a declared topic)
        def find_unknown_configs(as_new: false)
          UnknownConfigs.new(declaratives_routing_topics, existing_topics_names, as_new: as_new).call
        rescue Rdkafka::RdkafkaError => e
          raise_failed("Checking topics configuration", e)
        end

        # @return [Array<Hash>] existing topics details
        def existing_topics
          @existing_topics ||= Admin.cluster_info.topics
        end

        # @return [Array<String>] names of already existing topics
        def existing_topics_names
          existing_topics.map { |topic| topic.fetch(:topic_name) }
        end

        # Waits with a message, that we are waiting on topics
        # This is not doing much, just waiting as there are some cases that it takes a bit of time
        # for Kafka to actually propagate new topics knowledge across the cluster. We give it that
        # bit of time just in case.
        def wait
          print "Waiting for the topics to synchronize in the cluster"

          5.times do
            sleep(1)
            print "."
          end

          puts
        end
      end
    end
  end
end
