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

        # @return [Array<Karafka::Routing::Topic>] all available topics that can be managed
        # @note If topic is defined in multiple consumer groups, first config will be used. This
        #   means, that this CLI will not work for simultaneous management of multiple clusters
        #   from a single CLI command execution flow.
        def declaratives_routing_topics
          return @declaratives_routing_topics if @declaratives_routing_topics

          collected_topics = {}
          default_servers = kafka_config[:'bootstrap.servers']

          App.consumer_groups.each do |consumer_group|
            consumer_group.topics.each do |topic|
              # Skip topics that were explicitly disabled from management
              next unless topic.declaratives.active?
              # If bootstrap servers are different, consider this a different cluster
              next unless default_servers == topic.kafka[:'bootstrap.servers']

              collected_topics[topic.name] ||= topic
            end
          end

          @declaratives_routing_topics = collected_topics.values
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
          print 'Waiting for the topics to synchronize in the cluster'

          5.times do
            sleep(1)
            print '.'
          end

          puts
        end
      end
    end
  end
end
