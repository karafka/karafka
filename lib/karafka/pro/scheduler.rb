# frozen_string_literal: true

module Karafka
  module Pro
    # This Karafka component is a Pro component.
    # All of the commercial components are present in the lib/karafka/pro directory of this
    # repository and their usage requires commercial license agreement.
    #
    # Karafka has also commercial-friendly license, commercial support and commercial components.
    #
    # By sending a pull request to the pro components, you are agreeing to transfer the copyright
    # of your code to Maciej Mensfeld.

    # Optimizes scheduler that takes into consideration of execution time needed to process
    # messages from given topics partitions. It uses the non-preemptive LJF algorithm
    #
    # This scheduler is designed to optimize execution times on jobs that perform IO operations as
    # when taking IO into consideration, the can achieve optimized parallel processing.
    class Scheduler < ::Karafka::Scheduler
      # Yields messages from partitions in the LJF order
      #
      # @param messages_buffer [Karafka::Connection::MessagesBuffer] messages buffer with data from
      #   multiple topics and partitions
      # @yieldparam [String] topic name
      # @yieldparam [Integer] partition number
      # @yieldparam [Array<Rdkafka::Consumer::Message>] topic partition aggregated results
      def call(messages_buffer)
        pt = PerformanceTracker.instance

        ordered = []

        messages_buffer.each do |topic, partitions|
          partitions.each do |partition, messages|
            cost = pt.processing_time_p95(topic, partition)

            ordered << [topic, partition, messages, cost]
          end
        end

        ordered.sort_by!(&:last)
        ordered.reverse!

        ordered.each do |topic, partition, messages, _|
          yield(topic, partition, messages)
        end
      end
    end
  end
end
