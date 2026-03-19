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
    # Pro Admin utilities
    module Admin
      # Consumer group recovery toolkit.
      #
      # Provides coordinator-bypass offset reading and consumer group migration for scenarios
      # where the Kafka group coordinator is in a FAILED state and normal admin APIs return
      # NOT_COORDINATOR or time out.
      #
      # Works for any coordinator failure scenario:
      #   - KAFKA-19862 (compaction race during coordinator load)
      #   - Broker OOM / GC pause making coordinator unreachable
      #   - Network partition isolating the coordinator broker
      #   - Any future bug that transitions a coordinator shard to FAILED
      #
      # Migrating to a new consumer group often helps because each group is assigned to a specific
      # __consumer_offsets partition (and therefore a specific coordinator broker) based on its
      # name. When that coordinator enters a FAILED state, all operations for the group - joins,
      # heartbeats, offset commits, and offset fetches - are stuck until the coordinator recovers.
      #
      # Creating a new consumer group with a different name causes Kafka to hash it to a (likely)
      # different __consumer_offsets partition, served by a different, healthy coordinator. By
      # reading the committed offsets directly from the raw __consumer_offsets log (bypassing the
      # broken coordinator) and writing them to the new group via a healthy coordinator, consumers
      # can resume processing from exactly where they left off without waiting for the original
      # coordinator to recover.
      #
      # All reads go through the fetch API and never touch the group coordinator.
      #
      # @note These methods should NOT be used unless you are experiencing issues that require
      #   manual intervention. Misuse can lead to data loss or other problems.
      class Recovery < Karafka::Admin
        # Internal topic where Kafka stores committed offsets and group metadata
        OFFSETS_TOPIC = "__consumer_offsets"

        # Default lookback window for offset scanning (1 hour in ms). Covers any normal commit
        # interval. Increase if your group commits infrequently or the incident has been ongoing for
        # longer than 1 hour.
        DEFAULT_LOOKBACK_MS = 60 * 60 * 1_000

        class << self
          # @param consumer_group_id [String] consumer group to read offsets for
          # @param lookback_ms [Integer] how far back to start scanning in ms
          # @return [Hash{String => Hash{Integer => Integer}}]
          # @see #read_committed_offsets
          def read_committed_offsets(
            consumer_group_id,
            lookback_ms: DEFAULT_LOOKBACK_MS
          )
            new.read_committed_offsets(consumer_group_id, lookback_ms: lookback_ms)
          end

          # @param source_consumer_group_id [String] the broken/stuck consumer group
          # @param target_consumer_group_id [String] the new group to create
          # @param lookback_ms [Integer] how far back to scan for offsets
          # @return [Hash{String => Hash{Integer => Integer}}] the migrated offsets
          # @see #migrate_consumer_group
          def migrate_consumer_group(
            source_consumer_group_id,
            target_consumer_group_id,
            lookback_ms: DEFAULT_LOOKBACK_MS
          )
            new.migrate_consumer_group(
              source_consumer_group_id,
              target_consumer_group_id,
              lookback_ms: lookback_ms
            )
          end

          # @param consumer_group_id [String] consumer group id
          # @return [Integer] __consumer_offsets partition number
          # @see #offsets_partition_for
          def offsets_partition_for(consumer_group_id)
            new.offsets_partition_for(consumer_group_id)
          end
        end

        # Reads committed offsets for a consumer group directly from the __consumer_offsets internal
        # topic, bypassing the group coordinator. Only scans the single __consumer_offsets partition
        # that holds data for the given group (determined by Java's String#hashCode mod partition
        # count), starting from (now - lookback_ms) and reading forward to EOF. Later records
        # overwrite earlier ones so the result always reflects the most recent committed offset per
        # partition.
        #
        # @note All consumers in this group should be fully stopped before calling this method.
        #   While normally they would already be stopped due to a coordinator failure, if the
        #   cluster recovers concurrently, active consumers may commit newer offsets that this scan
        #   will not capture, resulting in stale data.
        #
        # @note This method may take a noticeable amount of time to complete because it scans
        #   the raw __consumer_offsets log from the lookback point forward to the end. The
        #   duration depends on the volume of offset commits in the lookback window across all
        #   consumer groups that hash to the same __consumer_offsets partition.
        #
        # @note The result only contains topic-partitions that had offsets committed within the
        #   lookback window. If a partition never had an offset committed, or if the commit happened
        #   before the lookback window, it will be absent from the result. It is the caller's
        #   responsibility to verify that all expected topic-partitions are present before using the
        #   result for migration or other operations.
        #
        # @param consumer_group_id [String] consumer group to read offsets for
        # @param lookback_ms [Integer] how far back to start scanning in ms
        # @return [Hash{String => Hash{Integer => Integer}}]
        #   { topic => { partition => committed_offset } }
        #
        # @example Read offsets for the last hour (default)
        #   Karafka::Admin::Recovery.read_committed_offsets('sync')
        #   #=> { 'events' => { 0 => 1400, 1 => 1402, ... } }
        #
        # @example Read offsets for the last 6 hours
        #   Karafka::Admin::Recovery.read_committed_offsets(
        #     'sync',
        #     lookback_ms: 6 * 60 * 60 * 1_000
        #   )
        #
        # @example Read offsets from a specific point in time
        #   since_ms = (Time.now - 7200).to_i * 1_000
        #   Karafka::Admin::Recovery.read_committed_offsets(
        #     'sync',
        #     lookback_ms: Time.now.to_i * 1_000 - since_ms
        #   )
        def read_committed_offsets(consumer_group_id, lookback_ms: DEFAULT_LOOKBACK_MS)
          start_time = Time.now - (lookback_ms / 1_000.0)
          committed = Hash.new { |h, k| h[k] = {} }
          target_partition = offsets_partition_for(consumer_group_id)

          iterator = Pro::Iterator.new(
            { OFFSETS_TOPIC => { target_partition => start_time } },
            settings: @custom_kafka
          )

          iterator.each do |message|
            next unless message.raw_key

            parsed = parse_offset_commit(message)
            next unless parsed
            next unless parsed[:group] == consumer_group_id

            # Last write wins - scanning forward means we naturally end up with the most recent
            # commit per partition
            committed[parsed[:topic]][parsed[:partition]] = parsed[:offset]
          end

          committed
        end

        # Migrates a stuck consumer group to a new group name, preserving exact committed offsets
        # recovered from the raw __consumer_offsets log. The source group is left in place - it will
        # clean up naturally once the coordinator recovers or the broker is patched. Safe to call
        # while the source group coordinator is in a FAILED state.
        #
        # @param source_consumer_group_id [String] the broken/stuck consumer group
        # @param target_consumer_group_id [String] the new group to create
        # @param lookback_ms [Integer] how far back to scan for offsets
        # @return [Hash{String => Hash{Integer => Integer}}] the migrated offsets
        #
        # @example Migrate to a new group name
        #   Karafka::Admin::Recovery.migrate_consumer_group('sync', 'sync_v2')
        #
        # @example Migrate with a longer lookback window
        #   Karafka::Admin::Recovery.migrate_consumer_group(
        #     'sync', 'sync_v2',
        #     lookback_ms: 4 * 60 * 60 * 1_000
        #   )
        def migrate_consumer_group(
          source_consumer_group_id,
          target_consumer_group_id,
          lookback_ms: DEFAULT_LOOKBACK_MS
        )
          consumer_groups = Karafka::Admin::ConsumerGroups.new(kafka: @custom_kafka)

          committed = read_committed_offsets(source_consumer_group_id, lookback_ms: lookback_ms)

          if committed.empty?
            raise(
              Errors::OperationError,
              "No committed offsets found for '#{source_consumer_group_id}'"
            )
          end

          consumer_groups.seek(target_consumer_group_id, committed)

          committed
        end

        # Determines which __consumer_offsets partition holds data for a given consumer group. Kafka
        # uses Utils.abs(String#hashCode) % numPartitions where hashCode is Java's 32-bit signed
        # hash: s[0]*31^(n-1) + s[1]*31^(n-2) + ... + s[n-1], computed with int32 overflow
        # semantics. Utils.abs maps Integer.MIN_VALUE to 0.
        #
        # @param consumer_group_id [String] consumer group id
        # @return [Integer] __consumer_offsets partition number
        #
        # @example Check which partition stores offsets for a group
        #   Karafka::Admin::Recovery.offsets_partition_for('my-group')
        #   #=> 17
        def offsets_partition_for(consumer_group_id)
          h = java_hash_code(consumer_group_id)
          # Kafka's Utils.abs: Integer.MIN_VALUE maps to 0
          h = (h == -2_147_483_648) ? 0 : h.abs
          h % offsets_partition_count
        end

        private

        # Parses a raw __consumer_offsets message into structured offset commit data
        #
        # @param message [Karafka::Messages::Message] raw message from __consumer_offsets
        # @return [Hash, nil] parsed offset commit or nil if not an offset commit record
        def parse_offset_commit(message)
          return nil unless message.raw_key

          key = message.raw_key.b
          record_type = key[0, 2].unpack1("n")
          return nil unless record_type == 1  # only offset commit records

          pos = 2
          gl = key[pos, 2].unpack1("n")
          pos += 2
          group = key[pos, gl].force_encoding("UTF-8")
          pos += gl
          tl = key[pos, 2].unpack1("n")
          pos += 2
          topic = key[pos, tl].force_encoding("UTF-8")
          pos += tl
          partition = key[pos, 4].unpack1("N")

          return nil unless message.raw_payload  # tombstone = offset deleted

          val = message.raw_payload.b

          # value layout: int16 version | int64 offset | ...
          offset = val[2, 8].unpack1("q>")

          { group: group, topic: topic, partition: partition, offset: offset }
        end

        # Computes Java's String#hashCode for a given string
        #
        # @param str [String] input string
        # @return [Integer] signed 32-bit hash value matching Java's String#hashCode
        def java_hash_code(str)
          hash = 0

          str.each_byte do |byte|
            # Emulate Java int32 overflow: multiply, add, then truncate to 32 bits
            hash = (hash * 31 + byte) & 0xFFFFFFFF
          end

          # Convert unsigned 32-bit to signed 32-bit (Java int semantics)
          (hash >= 0x80000000) ? hash - 0x100000000 : hash
        end

        # Returns the partition count of the __consumer_offsets topic.
        #
        # @return [Integer] number of partitions
        # @raise [Errors::OperationError] when topic metadata cannot be retrieved
        def offsets_partition_count
          topic_info = cluster_info.topics.find do |t|
            t[:topic_name] == OFFSETS_TOPIC
          end

          unless topic_info
            raise(
              Errors::OperationError,
              "Could not retrieve partition count for '#{OFFSETS_TOPIC}'"
            )
          end

          topic_info[:partition_count]
        end
      end
    end
  end
end

# We alias this for Pro users so we don't end up having two Admin namespaces from the end
# user perspective. This enhances the UX.
Karafka::Admin::Recovery = Karafka::Pro::Admin::Recovery
