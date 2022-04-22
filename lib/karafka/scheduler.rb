# frozen_string_literal: true

module Karafka
  # FIFO scheduler for messages coming from various topics and partitions
  class Scheduler
    # Yields messages from partitions in the fifo order
    #
    # @yieldparam [String] topic name
    # @yieldparam [Integer] partition number
    # @yieldparam [Array<Rdkafka::Consumer::Message>] topic partition aggregated results
    def call(messages_buffer)
      messages_buffer.each do |topic, partitions|
        partitions.each do |partition, messages|
          yield(topic, partition, messages)
        end
      end
    end
  end
end
