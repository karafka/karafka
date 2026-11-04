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
          puts "#{operation_message} #{red("failed")}:"
          puts e

          raise Errors::CommandValidationError, cause: e
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

        # Fails when any existing declarative topic has configuration that the cluster does not
        # know. Such configuration would never be applied, so we stop before changing anything.
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

        # @return [Hash{Karafka::Declaratives::Topic => Hash{String => String}}] existing
        #   declarative topics with their configs (names with values) that the cluster does not
        #   know and so could never be applied
        def unknown_configs
          @unknown_configs ||= begin
            topics = declaratives_routing_topics.select do |topic|
              !topic.declaratives.details.empty? && existing_topics_names.include?(topic.name)
            end

            topics_configs = Cluster::TopicsConfigs.new(topics.first.name) unless topics.empty?

            topics.each_with_object({}) do |topic, unknown|
              configs = topics_configs.unknown(topic.declaratives.details)
              unknown[topic] = configs unless configs.empty?
            end
          end
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
