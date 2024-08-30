# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module ScheduledMessages
      # Dispatcher responsible for dispatching the messages to appropriate target topics and for
      # dispatching other messages. All messages (aside from the once users dispatch with the
      # envelope) are sent via this dispatcher.
      #
      # Messages are buffered and dispatched in batches to improve dispatch performance.
      class Dispatcher
        # @return [Array<Hash>] buffer with message hashes for dispatch
        attr_reader :buffer

        # @param topic [String] consumed topic name
        # @param partition [Integer] consumed partition
        def initialize(topic, partition)
          @topic = topic
          @partition = partition
          @buffer = []
          @serializer = Serializer.new
        end

        # Prepares the scheduled message to the dispatch to the target topic. Extracts all the
        # "schedule_" details and prepares it, so the dispatched message goes with the expected
        # attributes to the desired location. Alongside of that it actually builds 2
        # (1 if logs off) messages: tombstone event matching the schedule so it is no longer valid
        # and the log message that has the same data as the dispatched message. Helpful when
        # debugging.
        #
        # @param message [Karafka::Messages::Message] message from the schedules topic.
        #
        # @note This method adds the message to the buffer, does **not** dispatch it.
        # @note It also produces needed tombstone event as well as an audit log message
        def <<(message)
          target_headers = message.raw_headers.merge(
            'schedule_source_topic' => @topic,
            'schedule_source_partition' => @partition.to_s,
            'schedule_source_offset' => message.offset.to_s,
            'schedule_source_key' => message.key
          ).compact

          target = {
            payload: message.raw_payload,
            headers: target_headers
          }

          extract(target, message.headers, :topic)
          extract(target, message.headers, :partition)
          extract(target, message.headers, :key)
          extract(target, message.headers, :partition_key)

          @buffer << target

          # Tombstone message so this schedule is no longer in use and gets removed from Kafka by
          # Kafka itself during compacting. It will not cancel it because already dispatched but
          # will cause it not to be sent again and will be marked as dispatched.
          @buffer << Proxy.tombstone(message: message)
        end

        # Builds and dispatches the state report message with schedules details
        #
        # @param tracker [Tracker]
        #
        # @note This is dispatched async because it's just a statistical metric.
        def state(tracker)
          config.producer.produce_async(
            topic: "#{@topic[0..-9]}states",
            payload: @serializer.state(tracker),
            key: 'state',
            partition: @partition,
            headers: { 'zlib' => 'true' }
          )
        end

        # Sends all messages to Kafka in a sync way.
        # We use sync with batches to prevent overloading.
        # When transactional producer in use, this will be wrapped in a transaction automatically.
        def flush
          until @buffer.empty?
            config.producer.produce_many_sync(
              # We can remove this prior to the dispatch because we only evict messages from the
              # daily buffer once dispatch is successful
              @buffer.shift(config.flush_batch_size)
            )
          end
        end

        private

        # @return [Karafka::Core::Configurable::Node] scheduled messages config node
        def config
          @config ||= Karafka::App.config.scheduled_messages
        end

        # Extracts and copies the future attribute to a proper place in the target message.
        #
        # @param target [Hash]
        # @param headers [Hash]
        # @param attribute [Symbol]
        def extract(target, headers, attribute)
          schedule_attribute = "schedule_target_#{attribute}"

          return unless headers.key?(schedule_attribute)

          target[attribute] = headers[schedule_attribute]
        end
      end
    end
  end
end
