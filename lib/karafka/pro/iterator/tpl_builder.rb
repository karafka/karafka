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
    class Iterator
      # Because we have various formats in which we can provide the offsets, before we can
      # subscribe to them, there needs to be a bit of normalization.
      #
      # For some of the cases, we need to go to Kafka and get the real offsets or watermarks.
      #
      # This builder resolves that and builds a tpl to which we can safely subscribe the way
      # we want it.
      class TplBuilder
        # Supported named offset positions that we can reference via their name
        SUPPORTED_NAMED_POSITIONS = %w[earliest latest].freeze

        private_constant :SUPPORTED_NAMED_POSITIONS

        # @param consumer [::Rdkafka::Consumer] consumer instance needed to talk with Kafka
        # @param expanded_topics [Hash] hash with expanded and normalized topics data
        def initialize(consumer, expanded_topics)
          @consumer = Karafka::Connection::Proxy.new(consumer)
          @expanded_topics = expanded_topics
          @mapped_topics = Hash.new { |h, k| h[k] = {} }
        end

        # @return [Rdkafka::Consumer::TopicPartitionList] final tpl we can use to subscribe
        def call
          resolve_partitions_without_offsets
          resolve_partitions_with_exact_offsets
          resolve_partitions_with_negative_offsets
          resolve_partitions_with_time_offsets
          resolve_partitions_with_named_offsets
          resolve_partitions_with_cg_expectations

          # Final tpl with all the data
          tpl = Rdkafka::Consumer::TopicPartitionList.new

          @mapped_topics.each do |name, partitions|
            tpl.add_topic_and_partitions_with_offsets(name, partitions)
          end

          tpl
        end

        private

        # First we expand on those partitions that do not have offsets defined.
        # When we operate in case like this, we just start from beginning
        def resolve_partitions_without_offsets
          @expanded_topics.each do |name, partitions|
            # We can here only about the case where we have partitions without offsets
            next unless partitions.is_a?(Array) || partitions.is_a?(Range)

            # When no offsets defined, we just start from zero
            @mapped_topics[name] = partitions.to_h { |partition| [partition, 0] }
          end
        end

        # If we get exact numeric offsets, we can just start from them without any extra work
        def resolve_partitions_with_exact_offsets
          @expanded_topics.each do |name, partitions|
            next unless partitions.is_a?(Hash)

            partitions.each do |partition, offset|
              # Skip negative and time based offsets
              next unless offset.is_a?(Integer) && offset >= 0

              # Exact offsets can be used as they are No need for extra operations
              @mapped_topics[name][partition] = offset
            end
          end
        end

        # If the offsets are negative, it means we want to fetch N last messages and we need to
        # figure out the appropriate offsets
        #
        # We do it by getting the watermark offsets and just calculating it. This means that for
        # heavily compacted topics, this may return less than the desired number but it is a
        # limitation that is documented.
        def resolve_partitions_with_negative_offsets
          # Collect all integer-offset partitions (positive and negative) and the subset
          # that actually need LWM/HWM resolution
          warm_up_partitions = {}
          negative_partitions = {}

          @expanded_topics.each do |name, partitions|
            next unless partitions.is_a?(Hash)

            partitions.each do |partition, offset|
              next unless offset.is_a?(Integer)

              (warm_up_partitions[name] ||= []) << partition
              (negative_partitions[name] ||= {})[partition] = offset if offset.negative?
            end
          end

          return if warm_up_partitions.empty?

          # A single batched offsets_for_times call on the consumer handle warms up
          # librdkafka's per-partition metadata cache for all integer-offset partitions in
          # one roundtrip. Without this pre-fetch, librdkafka triggers a much broader
          # metadata refresh when assign is called later, adding at least a second to
          # iterator startup — noticeable in latency-sensitive contexts like Puma.
          # The epoch timestamp ensures every partition returns its LWM; the result is
          # intentionally discarded since we only need the warm-up side effect here.
          warm_up_tpl = Rdkafka::Consumer::TopicPartitionList.new
          warm_up_partitions.each do |name, part_ids|
            warm_up_tpl.add_topic_and_partitions_with_offsets(
              name, part_ids.to_h { |p| [p, Time.at(0)] }
            )
          end
          @consumer.offsets_for_times(warm_up_tpl)

          return if negative_partitions.empty?

          # Batch-fetch LWM and HWM for all negative-offset partitions in two admin calls
          # (one for :earliest, one for :latest) instead of N per-partition consumer calls
          watermarks = Karafka::Admin::Topics.read_watermark_offsets(
            negative_partitions.transform_values(&:keys)
          )

          negative_partitions.each do |name, partitions|
            partitions.each do |partition, offset|
              # We add because this offset is negative
              low, high = watermarks.dig(name, partition) || [0, 0]
              @mapped_topics[name][partition] = [high + offset, low].max
            end
          end
        end

        # For time based offsets we first need to aggregate them and request the proper offsets.
        # We want to get all times in one go for all tpls defined with times, so we accumulate
        # them here and we will make one sync request to kafka for all.
        def resolve_partitions_with_time_offsets
          time_tpl = Rdkafka::Consumer::TopicPartitionList.new

          # First we need to collect the time based once
          @expanded_topics.each do |name, partitions|
            next unless partitions.is_a?(Hash)

            time_based = {}

            partitions.each do |partition, offset|
              next unless offset.is_a?(Time)

              time_based[partition] = offset
            end

            next if time_based.empty?

            time_tpl.add_topic_and_partitions_with_offsets(name, time_based)
          end

          # If there were no time-based, no need to query Kafka
          return if time_tpl.empty?

          real_offsets = @consumer.offsets_for_times(time_tpl)

          real_offsets.to_h.each do |name, results|
            results.each do |result|
              raise(Errors::InvalidTimeBasedOffsetError) unless result

              @mapped_topics[name][result.partition] = result.offset
            end
          end
        end

        # If we get named offsets, we can just remap them to librdkafka special offset positions
        def resolve_partitions_with_named_offsets
          @expanded_topics.each do |name, partitions|
            next unless partitions.is_a?(Hash)

            partitions.each do |partition, offset|
              # Skip offsets that do not match our named expectations
              named_offset = offset.to_s

              next unless SUPPORTED_NAMED_POSITIONS.include?(named_offset)

              @mapped_topics[name][partition] = -1 if named_offset == "latest"
              @mapped_topics[name][partition] = -2 if named_offset == "earliest"
            end
          end
        end

        # Fetches last used offsets for those partitions for which we want to consume from last
        # moment where given consumer group has finished
        # This is indicated by given partition value being set to `true`.
        def resolve_partitions_with_cg_expectations
          tpl = Rdkafka::Consumer::TopicPartitionList.new

          # First iterate over all topics that we want to expand
          @expanded_topics.each do |name, partitions|
            partitions_base = {}

            partitions.each do |partition, offset|
              # Pick only partitions where offset is set to true to indicate that we are interested
              # in committed offset resolution
              next unless offset == true

              # This can be set to nil because we do not use this offset value when querying
              partitions_base[partition] = nil
            end

            # If there is nothing to work with, just skip
            next if partitions_base.empty?

            tpl.add_topic_and_partitions_with_offsets(name, partitions_base)
          end

          # If nothing to resolve, do not resolve
          return if tpl.empty?

          # Fetch all committed offsets for all the topics partitions of our interest and use
          # those offsets for the mapped topics data
          @consumer.committed(tpl).to_h.each do |name, partitions|
            partitions.each do |partition|
              @mapped_topics[name][partition.partition] = partition.offset
            end
          end
        end
      end
    end
  end
end
