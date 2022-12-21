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

    # Defaults for config
    CONFIG_DEFAULTS = {
      'group.id': 'karafka_admin',
      # We want to know when there is no more data not to end up with an endless loop
      'enable.partition.eof': true,
      'statistics.interval.ms': 0
    }.freeze

    private_constant :Topic, :CONFIG_DEFAULTS

    class << self
      # Allows us to read messages from the topic
      #
      # @param name [String, Symbol] topic name
      # @param partition [Integer] partition
      # @param count [Integer] how many messages we want to get at most
      # @param start_offset [Integer] offset from which we should start. If -1 is provided
      #   (default) we will start from the latest offset
      #
      # @return [Array<Karafka::Messages::Message>] array with messages
      def read_topic(name, partition, count, start_offset = -1)
        messages = []
        tpl = Rdkafka::Consumer::TopicPartitionList.new

        with_consumer do |consumer|
          offsets = consumer.query_watermark_offsets(name, partition)
          end_offset = offsets.last

          start_offset = [0, offsets.last - count].max if start_offset.negative?

          tpl.add_topic_and_partitions_with_offsets(name, partition => start_offset)
          consumer.assign(tpl)

          # We should poll as long as we don't have all the messages that we need or as long as
          # we do not read all the messages from the topic
          loop do
            # If we've got as many messages as we've wanted stop
            break if messages.size >= count
            # If we've reached end of the topic messages, don't process more
            break if !messages.empty? && end_offset <= messages.last.offset

            message = consumer.poll(200)
            messages << message if message
          rescue Rdkafka::RdkafkaError => e
            # End of partition
            break if e.code == :partition_eof

            raise e
          end
        end

        messages.map do |message|
          Messages::Builders::Message.call(
            message,
            Topic.new(name, Karafka::App.config.deserializer),
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
        admin = config(:producer).admin
        yield(admin)
      ensure
        admin&.close
      end

      # Creates consumer instance and yields it. After usage it closes the consumer instance
      def with_consumer
        consumer = config(:consumer).consumer
        yield(consumer)
      ensure
        consumer&.close
      end

      # @param type [Symbol] type of config we want
      # @return [::Rdkafka::Config] rdkafka config
      def config(type)
        config_hash = Karafka::Setup::AttributesMap.public_send(
          type,
          Karafka::App.config.kafka.dup.merge(CONFIG_DEFAULTS)
        )

        ::Rdkafka::Config.new(config_hash)
      end
    end
  end
end
