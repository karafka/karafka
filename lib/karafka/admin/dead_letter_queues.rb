# frozen_string_literal: true

module Karafka
  class Admin
    # Dead letter queue operations
    # Provides methods to copy (replay) messages from a dead letter queue topic back to the topic
    # they came from or to any other topic
    class DeadLetterQueues < Admin
      # How many messages we read from a partition in one go before dispatching them
      BATCH_SIZE = 1_000

      # Headers the Pro DLQ adds to each dispatched message to describe its origin. They are
      # removed when copying, so the copied message carries only its original headers
      SOURCE_HEADERS = %w[
        source_topic
        source_partition
        source_offset
        source_consumer_group
        source_attempts
        source_trace_id
      ].freeze

      # Header with the number of times a message was copied out of a dead letter queue
      REPLAY_COUNT_HEADER = "replay_count"

      private_constant :BATCH_SIZE, :SOURCE_HEADERS, :REPLAY_COUNT_HEADER

      class << self
        # @param topic_name [String] dead letter queue topic name
        # @param target_topic_name [String, nil] topic to copy messages to
        # @param partitions [Array<Integer>, nil] partitions to copy from (all when nil)
        # @param start_offset [Integer, Time] offset (inclusive) or time from which to copy
        # @param end_offset [Integer, nil] offset (exclusive) until which to copy
        # @param producer [WaterDrop::Producer, nil] producer to dispatch with
        # @see #copy
        def copy(
          topic_name,
          target_topic_name: nil,
          partitions: nil,
          start_offset: 0,
          end_offset: nil,
          producer: nil
        )
          new.copy(
            topic_name,
            target_topic_name: target_topic_name,
            partitions: partitions,
            start_offset: start_offset,
            end_offset: end_offset,
            producer: producer
          )
        end
      end

      # Copies messages of a dead letter queue topic to a target topic, so they can be processed
      # again.
      #
      # Each message is dispatched with its raw payload and key. When the message carries the
      # Pro DLQ `source_topic` header and no `target_topic_name` is given, it is dispatched to
      # its `source_topic` and `source_partition`. The Pro DLQ `source_*` headers are removed,
      # the other headers are kept and the `replay_count` header is incremented, so a message
      # that fails again and is copied again can be detected as a replay loop.
      #
      # @param topic_name [String] dead letter queue topic name
      # @param target_topic_name [String, nil] topic to copy all the messages to. When nil, each
      #   message is copied to its Pro DLQ `source_topic` header
      # @param partitions [Array<Integer>, nil] partitions to copy from. All when nil
      # @param start_offset [Integer, Time] offset (inclusive) or time from which to copy in each
      #   partition. Defaults to the first available message
      # @param end_offset [Integer, nil] offset (exclusive) until which to copy in each partition.
      #   When nil, copies until the high watermark offset at the time of the call, so messages
      #   that land in the dead letter queue during the copy are not copied
      # @param producer [WaterDrop::Producer, nil] producer to dispatch with. `Karafka.producer`
      #   when nil
      #
      # @return [Integer] number of copied messages
      #
      # @raise [Karafka::Errors::SourceTopicMissingError] when no `target_topic_name` is given
      #   and a message has no `source_topic` header. Messages of the batch in which this
      #   happens are not dispatched, messages of earlier batches are
      #
      # @note The OSS DLQ dispatches only the payload, without the key, the headers or the
      #   source topic, so its messages need `target_topic_name` and are copied without a key
      #   and original headers.
      #
      # @note The copy is not atomic. A failure in the middle leaves earlier batches dispatched.
      #
      # @example Copy all messages of a Pro DLQ topic back to their source topics
      #   Karafka::Admin.copy_dead_letter_queue('events_dlq')
      #
      # @example Copy a range of messages of one partition to a given topic
      #   Karafka::Admin.copy_dead_letter_queue(
      #     'events_dlq',
      #     target_topic_name: 'events',
      #     partitions: [0],
      #     start_offset: 100,
      #     end_offset: 200
      #   )
      def copy(
        topic_name,
        target_topic_name: nil,
        partitions: nil,
        start_offset: 0,
        end_offset: nil,
        producer: nil
      )
        Contracts::DeadLetterQueues.new.validate!(
          {
            topic_name: topic_name,
            target_topic_name: target_topic_name,
            partitions: partitions,
            start_offset: start_offset,
            end_offset: end_offset
          }
        )

        topics = Topics.new(kafka: @custom_kafka, external_client: @external_client)
        producer ||= Karafka.producer
        partitions ||= topics.info(topic_name).fetch(:partitions).map { |p| p.fetch(:partition_id) }

        partitions.sum do |partition|
          copy_partition(
            topics,
            producer,
            topic_name,
            partition,
            target_topic_name,
            start_offset,
            end_offset
          )
        end
      end

      private

      # @param topics [Topics] topics admin to read with
      # @param producer [WaterDrop::Producer] producer to dispatch with
      # @param topic_name [String] dead letter queue topic name
      # @param partition [Integer] partition to copy from
      # @param target_topic_name [String, nil] topic to copy to
      # @param start_offset [Integer, Time] offset or time from which to copy
      # @param end_offset [Integer, nil] offset (exclusive) until which to copy
      # @return [Integer] number of copied messages
      def copy_partition(
        topics,
        producer,
        topic_name,
        partition,
        target_topic_name,
        start_offset,
        end_offset
      )
        high_offset = topics.read_watermark_offsets(topic_name, partition).last
        end_offset = end_offset ? [end_offset, high_offset].min : high_offset
        offset = start_offset
        copied = 0

        loop do
          break if offset.is_a?(Integer) && offset >= end_offset

          batch = topics.read(topic_name, partition, BATCH_SIZE, offset)
          batch.select! { |message| message.offset < end_offset }

          break if batch.empty?

          producer.produce_many_sync(
            batch.map { |message| build_message(message, target_topic_name) }
          )

          copied += batch.size
          offset = batch.last.offset + 1
        end

        copied
      end

      # @param message [Karafka::Messages::Message] dead letter queue message
      # @param target_topic_name [String, nil] topic to copy to
      # @return [Hash] message to dispatch
      def build_message(message, target_topic_name)
        headers = message.raw_headers.dup
        source_topic = headers["source_topic"]

        unless target_topic_name || source_topic
          raise(
            Errors::SourceTopicMissingError,
            "#{message.topic}/#{message.partition}/#{message.offset}"
          )
        end

        dispatched = {
          topic: target_topic_name || source_topic,
          payload: message.raw_payload,
          headers: headers
        }

        dispatched[:key] = message.raw_key if message.raw_key

        if source_topic
          source_partition = headers["source_partition"]
          dispatched[:partition] = source_partition.to_i if !target_topic_name && source_partition

          SOURCE_HEADERS.each { |header| headers.delete(header) }
        end

        headers[REPLAY_COUNT_HEADER] = (headers[REPLAY_COUNT_HEADER].to_i + 1).to_s

        dispatched
      end
    end
  end
end
