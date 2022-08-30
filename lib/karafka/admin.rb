# frozen_string_literal: true

module Karafka
  # Simple admin actions that we can perform via Karafka on our Kafka cluster
  #
  # @note It always initializes a new admin instance as we want to ensure it is always closed
  #   Since admin actions are not performed that often, that should be ok.
  #
  # @note It always uses the primary defined cluster and does not support multi-cluster work.
  #   If you need this, just replace the cluster info for the time you use this
  module Admin
    class << self
      # Creates Kafka topic with given settings
      #
      # @param name [String] topic name
      # @param partitions [Integer] number of partitions we expect
      # @param replication_factor [Integer] number of replicas
      # @param topic_config [Hash] topic config details as described here:
      #   https://kafka.apache.org/documentation/#topicconfigs
      def create_topic(name, partitions, replication_factor, topic_config = {})
        with_admin do |admin|
          admin.create_topic(name, partitions, replication_factor, topic_config)

          sleep(0.1) until topics_names.include?(name)
        end
      end

      # Deleted a given topic
      #
      # @param name [String] topic name
      def delete_topic(name)
        with_admin do |admin|
          admin.delete_topic(name)

          sleep(0.1) while topics_names.include?(name)
        end
      end

      # @return [Rdkafka::Metadata] cluster metadata info
      def cluster_info
        with_admin do |admin|
          Rdkafka::Metadata.new(admin.instance_variable_get('@native_kafka'))
        end
      end

      private

      # @return [Array<String>] topics names
      def topics_names
        cluster_info.topics.map { |topic| topic.fetch(:topic_name) }
      end

      # Creates admin instance and yields it. After usage it closes the admin instance
      def with_admin
        admin = ::Rdkafka::Config.new(Karafka::App.config.kafka).admin
        result = yield(admin)
        result
      ensure
        admin&.close
      end
    end
  end
end
