# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    # Tracker used to keep track of performance metrics
    # It provides insights that can be used to optimize processing flow
    class PerformanceTracker
      include Singleton

      # How many samples do we collect per topic partition
      SAMPLES_COUNT = 200

      private_constant :SAMPLES_COUNT

      # Builds up nested concurrent hash for data tracking
      def initialize
        @processing_times = Concurrent::Hash.new do |topics_hash, topic|
          topics_hash[topic] = Concurrent::Hash.new do |partitions_hash, partition|
            # This array does not have to be concurrent because we always access single partition
            # data via instrumentation that operates in a single thread via consumer
            partitions_hash[partition] = []
          end
        end
      end

      # @param topic [String]
      # @param partition [Integer]
      # @return [Float] p95 processing time of a single message from a single topic partition
      def processing_time_p95(topic, partition)
        values = @processing_times[topic][partition]

        return 0 if values.empty?
        return values.first if values.size == 1

        percentile(0.95, values)
      end

      # @private
      # @param event [Karafka::Core::Monitoring::Event] event details
      # Tracks time taken to process a single message of a given topic partition
      def on_consumer_consumed(event)
        consumer = event[:caller]
        messages = consumer.messages
        topic = messages.metadata.topic
        partition = messages.metadata.partition

        samples = @processing_times[topic][partition]
        samples << event[:time] / messages.count

        return unless samples.size > SAMPLES_COUNT

        samples.shift
      end

      private

      # Computers the requested percentile out of provided values
      # @param percentile [Float]
      # @param values [Array<String>] all the values based on which we should
      # @return [Float] computed percentile
      def percentile(percentile, values)
        values_sorted = values.sort

        floor = (percentile * (values_sorted.length - 1) + 1).floor - 1
        mod = (percentile * (values_sorted.length - 1) + 1).modulo(1)

        values_sorted[floor] + (mod * (values_sorted[floor + 1] - values_sorted[floor]))
      end
    end
  end
end
