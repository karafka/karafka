# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    # Namespace for Pro components instrumentation related code
    module Instrumentation
      # Tracker used to keep track of performance metrics
      # It provides insights that can be used to optimize processing flow
      # @note Even if we have some race-conditions here it is relevant due to the quantity of data.
      #   This is why we do not mutex it.
      class PerformanceTracker
        include Singleton

        # How many samples do we collect per topic partition
        SAMPLES_COUNT = 200

        private_constant :SAMPLES_COUNT

        # Builds up nested concurrent hash for data tracking
        def initialize
          @processing_times = Hash.new do |topics_hash, topic|
            topics_hash[topic] = Hash.new do |partitions_hash, partition|
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
          samples << (event[:time] / messages.size)

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

          floor = ((percentile * (values_sorted.length - 1)) + 1).floor - 1
          mod = ((percentile * (values_sorted.length - 1)) + 1).modulo(1)

          values_sorted[floor] + (mod * (values_sorted[floor + 1] - values_sorted[floor]))
        end
      end
    end
  end
end
