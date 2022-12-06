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
    # A fake admin topic representation that we use for messages fetched using this API
    # We cannot use the topics directly because we may want to request data from topics that we
    # do not have in the routing
    Topic = Struct.new(:name, :deserializer)

    private_constant :Topic

    class << self
      # Allows us to read messages from the topic
      #
      # @param name [String, Symbol] topic name
      # @param partition [Integer] partition
      # @param count [Integer] how many messages we want to get at most
      #
      # @return [Array<Karafka::Messages::Message>] array with messages
      def read_topic(name, partition, count = 1)
        messages = []

        with_consumer do |consumer|
          offsets = consumer.query_watermark_offsets(name, partition)
          tpl = Rdkafka::Consumer::TopicPartitionList.new

          offset = offsets.last - count
          offset = offset.negative? ? 0 : offset

          tpl.add_topic_and_partitions_with_offsets(name, partition => offset)
          consumer.assign(tpl)

          # We should poll as long as we don't have all the messages that we need or as long as
          # we do not read all the messages from the topic
          while messages.size < count && messages.size < offsets.last
            message = consumer.poll(200)
            messages << message if message
          end
        end

        topic = Topic.new(
          name,
          Karafka::App.config.deserializer
        )

        messages.map do |message|
          Messages::Builders::Message.call(
            message,
            topic,
            Time.now
          )
        end
      end

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

          sleep(0.2) until topics_names.include?(name)
        end
      end

      # Deleted a given topic
      #
      # @param name [String] topic name
      def delete_topic(name)
        with_admin do |admin|
          admin.delete_topic(name)

          sleep(0.2) while topics_names.include?(name)
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
        # Admin needs a producer config
        config = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)

        admin = ::Rdkafka::Config.new(config).admin
        result = yield(admin)
        result
      ensure
        admin&.close
      end

      def with_consumer
        config = Karafka::Setup::AttributesMap.consumer(
          Karafka::App.config.kafka.dup
        ).merge('group.id': 'karafka_admin')

        consumer = ::Rdkafka::Config.new(config).consumer
        result = yield(consumer)
        result
      ensure
        consumer&.close
      end
    end
  end
end
