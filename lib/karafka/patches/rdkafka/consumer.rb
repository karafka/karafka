# frozen_string_literal: true

module Karafka
  # Patches to external components
  module Patches
    # Rdkafka related patches
    module Rdkafka
      # Rdkafka::Consumer patches
      module Consumer
        # A method that allows us to get the native kafka producer name
        # @return [String] producer instance name
        # @note We need this to make sure that we allocate proper dispatched events only to
        #   callback listeners that should publish them
        def name
          ::Rdkafka::Bindings.rd_kafka_name(@native_kafka)
        end
      end
    end
  end
end

::Rdkafka::Consumer.include ::Karafka::Patches::Rdkafka::Consumer


class Rdkafka::Consumer
        # Seek to a particular message. The next poll on the topic/partition will return the
        # message at the given offset.
        #
        # @param message [Rdkafka::Consumer::Message] The message to which to seek
        # @param timeout_ms [Integer] how long should we wait for sync seeking (async if 0)
        # @raise [RdkafkaError] When seeking fails
        #
        # @return [nil]
        def seek(message, timeout_ms = 0)
          closed_consumer_check(__method__)

          # rd_kafka_offset_store is one of the few calls that does not support
          # a string as the topic, so create a native topic for it.
          native_topic = Rdkafka::Bindings.rd_kafka_topic_new(
            @native_kafka,
            message.topic,
            nil
          )
          response = Rdkafka::Bindings.rd_kafka_seek(
            native_topic,
            message.partition,
            message.offset,
            1_000
          )
          if response != 0
            raise Rdkafka::RdkafkaError.new(response)
          end
        rescue StandardError => e
          p e
        ensure
          if native_topic && !native_topic.null?
            Rdkafka::Bindings.rd_kafka_topic_destroy(native_topic)
          end
        end
end