# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
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
        #
        # @note Samples are scoped by subscription group id so that two groups consuming the same
        #   topic name keep independent measurements - and so revoking a partition in one group
        #   never drops samples another group is still using.
        def initialize
          @processing_times = Hash.new do |groups_hash, group_id|
            groups_hash[group_id] = Hash.new do |topics_hash, topic|
              topics_hash[topic] = Hash.new do |partitions_hash, partition|
                partitions_hash[partition] = []
              end
            end
          end
        end

        # @param group_id [String] subscription group id the topic partition belongs to
        # @param topic [String]
        # @param partition [Integer]
        # @return [Float] p95 processing time of a single message from a single topic partition
        def processing_time_p95(group_id, topic, partition)
          values = @processing_times[group_id][topic][partition]

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
          group_id = consumer.topic.subscription_group.id
          topic = messages.metadata.topic
          partition = messages.metadata.partition

          samples = @processing_times[group_id][topic][partition]
          samples << (event[:time] / messages.size)

          return unless samples.size > SAMPLES_COUNT

          samples.shift
        end

        # @param event [Karafka::Core::Monitoring::Event] rebalance revoked event details
        # Evicts the processing time samples of revoked partitions so the tracker does not retain
        # them for the whole process lifetime. Without this every (topic, partition) ever consumed
        # keeps its samples array forever - unbounded under regex pattern subscriptions that keep
        # discovering new topic names. Mirrors the offset metadata fetcher, which also clears on
        # revoke. Samples are scoped by subscription group, so we only ever evict the revoked
        # group's data and never another group consuming the same topic.
        def on_rebalance_partitions_revoked(event)
          group_id = event[:subscription_group_id]

          # Do not auto-vivify a branch for a group we have never tracked
          return unless @processing_times.key?(group_id)

          group_times = @processing_times[group_id]

          event[:tpl].to_h.each do |topic, partitions|
            next unless group_times.key?(topic)

            topic_times = group_times[topic]
            partitions.each { |partition| topic_times.delete(partition.partition) }
            group_times.delete(topic) if topic_times.empty?
          end

          @processing_times.delete(group_id) if group_times.empty?
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
