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

        # @param kafka [Hash] custom Kafka configuration for the target cluster
        def initialize(kafka: {})
          super()

          @kafka = kafka
        end

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
        # @note Topics with bootstrap servers that differ from the target Kafka config are
        #   excluded. Standalone topics without bootstrap servers belong to the default cluster.
        def declaratives_routing_topics
          @declaratives_routing_topics ||= begin
            default_servers = kafka_config[:"bootstrap.servers"]
            target_servers = @kafka.fetch(:"bootstrap.servers") do
              @kafka.fetch("bootstrap.servers", default_servers)
            end

            App.declaratives.topics.reject do |topic|
              (topic.bootstrap_servers || default_servers) != target_servers
            end
          end
        end

        # @return [Array<Hash>] existing topics details
        def existing_topics
          @existing_topics ||= admin.cluster_info.topics
        end

        # @return [Array<String>] names of already existing topics
        def existing_topics_names
          existing_topics.map { |topic| topic.fetch(:topic_name) }
        end

        def admin
          @admin ||= @kafka.empty? ? Admin : Admin.new(kafka: @kafka)
        end

        def configs_admin
          @configs_admin ||= @kafka.empty? ? Admin::Configs : Admin::Configs.new(kafka: @kafka)
        end

        def build_command(command)
          @kafka.empty? ? command.new : command.new(kafka: @kafka)
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
