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

          # @param consumer_group_id [String] consumer group to look up
          # @return [Hash] coordinator broker info
          # @see #coordinator_for
          def coordinator_for(consumer_group_id)
            new.coordinator_for(consumer_group_id)
          end

          # @param partition [Integer] __consumer_offsets partition to scan
          # @param lookback_ms [Integer] how far back to start scanning in ms
          # @return [Array<String>] sorted consumer group names
          # @see #affected_groups
          def affected_groups(partition, lookback_ms: DEFAULT_LOOKBACK_MS)
            new.affected_groups(partition, lookback_ms: lookback_ms)
          end

          # @param broker_id [Integer] broker node id
          # @return [Array<Integer>] sorted partition numbers
          # @see #affected_partitions
          def affected_partitions(broker_id)
            new.affected_partitions(broker_id)
          end

          # @param consumer_group_id [String] consumer group to read lags for
          # @param lookback_ms [Integer] how far back to start scanning in ms
          # @return [Hash] offsets with lag information
          # @see #read_committed_lags
          def read_committed_lags(consumer_group_id, lookback_ms: DEFAULT_LOOKBACK_MS)
            new.read_committed_lags(consumer_group_id, lookback_ms: lookback_ms)
          end

          # @param mapping [Hash{String => String}] source to target group mapping
          # @param lookback_ms [Integer] how far back to start scanning in ms
          # @return [Hash] migrated offsets keyed by source group
          # @see #migrate_consumer_groups
          def migrate_consumer_groups(mapping, lookback_ms: DEFAULT_LOOKBACK_MS)
            new.migrate_consumer_groups(mapping, lookback_ms: lookback_ms)
          end

          # @param consumer_group_id [String] consumer group to check
          # @param lookback_ms [Integer] how far back to start scanning in ms
          # @return [Hash] anomaly report per topic/partition
          # @see #detect_offset_anomalies
          def detect_offset_anomalies(consumer_group_id, lookback_ms: DEFAULT_LOOKBACK_MS)
            new.detect_offset_anomalies(consumer_group_id, lookback_ms: lookback_ms)
          end

          # @param source_group [String] source consumer group
          # @param target_group [String] target consumer group
          # @param lookback_ms [Integer] how far back to start scanning in ms
          # @return [Hash] verification result with status and mismatches
          # @see #verify_migration
          def verify_migration(source_group, target_group, lookback_ms: DEFAULT_LOOKBACK_MS)
            new.verify_migration(source_group, target_group, lookback_ms: lookback_ms)
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

        # Returns which broker is the coordinator for a consumer group. The coordinator is the
        # leader of the __consumer_offsets partition assigned to this group. Pure metadata lookup
        # that does not scan any topic data.
        #
        # Use this to quickly identify which broker is responsible for a consumer group. During an
        # incident, this tells you whether a specific group is affected by a broker outage. If the
        # returned broker is the one that is down or in a FAILED state, the group is stuck and
        # needs migration.
        #
        # @param consumer_group_id [String] consumer group to look up
        # @return [Hash{Symbol => Object}] coordinator info with :partition, :broker_id,
        #   and :broker_host keys
        #
        # @example Find coordinator for a group
        #   Karafka::Admin::Recovery.coordinator_for('my-group')
        #   #=> { partition: 17, broker_id: 2, broker_host: "broker2:9092" }
        #
        # @example Check if a group is affected by a broker outage
        #   info = Karafka::Admin::Recovery.coordinator_for('my-group')
        #   if info[:broker_id] == failed_broker_id
        #     puts "Group 'my-group' is stuck on failed broker #{info[:broker_host]}"
        #   end
        def coordinator_for(consumer_group_id)
          target_partition = offsets_partition_for(consumer_group_id)
          metadata = cluster_info

          offsets_topic = metadata.topics.find { |t| t[:topic_name] == OFFSETS_TOPIC }

          unless offsets_topic
            raise(
              Errors::OperationError,
              "Could not retrieve metadata for '#{OFFSETS_TOPIC}'"
            )
          end

          partitions = offsets_topic[:partitions]
          partition_info = partitions.find { |p| p[:partition_id] == target_partition }

          unless partition_info
            raise(
              Errors::OperationError,
              "Could not find partition #{target_partition} in '#{OFFSETS_TOPIC}'"
            )
          end

          leader_id = partition_info[:leader]

          broker = metadata.brokers.find do |b|
            if b.is_a?(Hash)
              (b[:broker_id] || b[:node_id]) == leader_id
            else
              b.node_id == leader_id
            end
          end

          unless broker
            raise(
              Errors::OperationError,
              "Could not find broker #{leader_id} in cluster metadata"
            )
          end

          if broker.is_a?(Hash)
            host = broker[:broker_name] || broker[:host]
            port = broker[:broker_port] || broker[:port]
            broker_host = "#{host}:#{port}"
            broker_id = broker[:broker_id] || broker[:node_id]
          else
            broker_host = "#{broker.host}:#{broker.port}"
            broker_id = broker.node_id
          end

          { partition: target_partition, broker_id: broker_id, broker_host: broker_host }
        end

        # Scans a __consumer_offsets partition and returns all consumer group names found. Use
        # this to discover which consumer groups are affected when a coordinator broker fails.
        #
        # Combined with {#affected_partitions}, this gives the full blast radius of a broker
        # outage: first find which __consumer_offsets partitions the failed broker leads, then
        # scan each partition to discover all affected consumer groups.
        #
        # @param partition [Integer] __consumer_offsets partition to scan
        # @param lookback_ms [Integer] how far back to start scanning in ms
        # @return [Array<String>] sorted list of consumer group names found
        #
        # @example Find all groups on partition 17
        #   Karafka::Admin::Recovery.affected_groups(17)
        #   #=> ["group-a", "group-b", "group-c"]
        #
        # @example Full blast radius of a broker outage
        #   partitions = Karafka::Admin::Recovery.affected_partitions(failed_broker_id)
        #   all_affected = partitions.flat_map do |p|
        #     Karafka::Admin::Recovery.affected_groups(p)
        #   end.uniq
        def affected_groups(partition, lookback_ms: DEFAULT_LOOKBACK_MS)
          count = offsets_partition_count

          unless partition >= 0 && partition < count
            raise(
              Errors::OperationError,
              "Partition #{partition} is out of range (0...#{count})"
            )
          end

          start_time = Time.now - (lookback_ms / 1_000.0)
          groups = Set.new

          iterator = Pro::Iterator.new(
            { OFFSETS_TOPIC => { partition => start_time } },
            settings: @custom_kafka
          )

          iterator.each do |message|
            next unless message.raw_key

            parsed = parse_offset_commit(message)
            next unless parsed

            groups << parsed[:group]
          end

          groups.sort
        end

        # Returns all __consumer_offsets partitions led by a given broker. Pure metadata lookup
        # that does not scan any topic data.
        #
        # Use this as the first step in assessing the blast radius of a broker outage. The
        # returned partition numbers can be passed to {#affected_groups} to discover all consumer
        # groups that need recovery or migration.
        #
        # @param broker_id [Integer] broker node id
        # @return [Array<Integer>] sorted list of __consumer_offsets partition numbers
        #
        # @example Find partitions led by broker 2
        #   Karafka::Admin::Recovery.affected_partitions(2)
        #   #=> [3, 17, 28, 42]
        def affected_partitions(broker_id)
          metadata = cluster_info

          offsets_topic = metadata.topics.find { |t| t[:topic_name] == OFFSETS_TOPIC }

          unless offsets_topic
            raise(
              Errors::OperationError,
              "Could not retrieve metadata for '#{OFFSETS_TOPIC}'"
            )
          end

          offsets_topic[:partitions]
            .select { |p| p[:leader] == broker_id }
            .map { |p| p[:partition_id] }
            .sort
        end

        # Like {#read_committed_offsets} but also fetches high watermarks and computes lag.
        # Watermark queries go directly to partition leaders, not through the coordinator, so
        # this works even when the coordinator is in a FAILED state.
        #
        # Use this to assess the backlog a consumer group will need to process after recovery.
        # The lag tells you how many messages are pending per partition, helping you decide
        # whether to migrate to a new group immediately or wait for the coordinator to recover.
        #
        # @param consumer_group_id [String] consumer group to read lags for
        # @param lookback_ms [Integer] how far back to start scanning in ms
        # @return [Hash{String => Hash{Integer => Hash{Symbol => Integer}}}]
        #   { topic => { partition => { offset:, lag:, hi_offset: } } }
        #
        # @example Read lags for a group
        #   Karafka::Admin::Recovery.read_committed_lags('my-group')
        #   #=> { 'events' => { 0 => { offset: 100, lag: 50, hi_offset: 150 } } }
        #
        # @example Estimate total pending messages
        #   lags = Karafka::Admin::Recovery.read_committed_lags('my-group')
        #   total = lags.sum { |_, parts| parts.sum { |_, v| v[:lag] } }
        def read_committed_lags(consumer_group_id, lookback_ms: DEFAULT_LOOKBACK_MS)
          committed = read_committed_offsets(consumer_group_id, lookback_ms: lookback_ms)
          return committed if committed.empty?

          result = Hash.new { |h, k| h[k] = {} }

          with_consumer do |consumer|
            committed.each do |topic, partitions|
              partitions.each do |partition, offset|
                _, hi_offset = consumer.query_watermark_offsets(topic, partition)
                lag = [hi_offset - offset, 0].max
                result[topic][partition] = { offset: offset, lag: lag, hi_offset: hi_offset }
              end
            end
          end

          result
        end

        # Migrates multiple consumer groups in batch. Groups sources by __consumer_offsets partition
        # so that each partition is scanned only once, even when multiple source groups hash to the
        # same partition. This is more efficient than calling {#migrate_consumer_group} repeatedly
        # because groups sharing the same __consumer_offsets partition are scanned together.
        #
        # Use this when a broker outage affects multiple consumer groups and you need to migrate
        # them all at once. First use {#affected_partitions} and {#affected_groups} to discover
        # the affected groups, then batch-migrate them in a single call.
        #
        # @param mapping [Hash{String => String}] source group to target group mapping
        # @param lookback_ms [Integer] how far back to start scanning in ms
        # @return [Hash{String => Hash{String => Hash{Integer => Integer}}}]
        #   { source_group => { topic => { partition => offset } } }
        #
        # @raise [Errors::OperationError] if any source group has no committed offsets
        #
        # @example Migrate two groups at once
        #   Karafka::Admin::Recovery.migrate_consumer_groups(
        #     { 'sync' => 'sync_v2', 'async' => 'async_v2' }
        #   )
        #
        # @example Migrate all groups affected by a broker outage
        #   affected = Karafka::Admin::Recovery.affected_partitions(2).flat_map do |p|
        #     Karafka::Admin::Recovery.affected_groups(p)
        #   end.uniq
        #   mapping = affected.each_with_object({}) { |g, h| h[g] = "#{g}_v2" }
        #   Karafka::Admin::Recovery.migrate_consumer_groups(mapping)
        def migrate_consumer_groups(mapping, lookback_ms: DEFAULT_LOOKBACK_MS)
          consumer_groups = Karafka::Admin::ConsumerGroups.new(kafka: @custom_kafka)
          start_time = Time.now - (lookback_ms / 1_000.0)

          # Group sources by __consumer_offsets partition for efficient scanning
          partition_to_sources = Hash.new { |h, k| h[k] = [] }

          mapping.each_key do |source|
            partition_to_sources[offsets_partition_for(source)] << source
          end

          # Collect offsets for all sources, scanning each partition only once
          all_offsets = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }

          partition_to_sources.each do |partition, sources|
            source_set = sources.to_set

            iterator = Pro::Iterator.new(
              { OFFSETS_TOPIC => { partition => start_time } },
              settings: @custom_kafka
            )

            iterator.each do |message|
              next unless message.raw_key

              parsed = parse_offset_commit(message)
              next unless parsed
              next unless source_set.include?(parsed[:group])

              all_offsets[parsed[:group]][parsed[:topic]][parsed[:partition]] = parsed[:offset]
            end
          end

          # Check for sources with no offsets
          missing = mapping.keys.select { |source| all_offsets[source].empty? }

          unless missing.empty?
            raise(
              Errors::OperationError,
              "No committed offsets found for: #{missing.join(", ")}"
            )
          end

          # Seek each target group
          mapping.each do |source, target|
            consumer_groups.seek(target, all_offsets[source])
          end

          # Convert to plain hashes for return
          all_offsets.transform_values do |topics|
            topics.transform_values(&:to_h).to_h
          end.to_h
        end

        # Compares committed offsets against watermarks to find out-of-range offsets. Watermark
        # queries go directly to partition leaders, not through the coordinator.
        #
        # Use this after recovery or migration to verify that all committed offsets are still
        # valid. Detects two anomaly types:
        #   - :expired — offset is below the low watermark, meaning data has been lost to
        #     retention and the consumer will skip messages on resume
        #   - :future — offset is above the high watermark, which should not happen under normal
        #     circumstances and may indicate data corruption or a bug
        #
        # @param consumer_group_id [String] consumer group to check
        # @param lookback_ms [Integer] how far back to start scanning in ms
        # @return [Hash{String => Hash{Integer => Hash{Symbol => Object}}}]
        #   { topic => { partition => { offset:, lo_offset:, hi_offset:, status: } } }
        #   where status is :ok, :expired, or :future
        #
        # @example Detect anomalies after recovery
        #   Karafka::Admin::Recovery.detect_offset_anomalies('my-group')
        #   #=> { 'events' => { 0 => { offset: 100, lo_offset: 0, hi_offset: 150, status: :ok } } }
        #
        # @example Flag partitions that need attention
        #   anomalies = Karafka::Admin::Recovery.detect_offset_anomalies('my-group')
        #   anomalies.each do |topic, partitions|
        #     partitions.each do |partition, info|
        #       next if info[:status] == :ok
        #       puts "#{topic}/#{partition}: #{info[:status]} (offset #{info[:offset]})"
        #     end
        #   end
        def detect_offset_anomalies(consumer_group_id, lookback_ms: DEFAULT_LOOKBACK_MS)
          committed = read_committed_offsets(consumer_group_id, lookback_ms: lookback_ms)
          return committed if committed.empty?

          result = Hash.new { |h, k| h[k] = {} }

          with_consumer do |consumer|
            committed.each do |topic, partitions|
              partitions.each do |partition, offset|
                lo_offset, hi_offset = consumer.query_watermark_offsets(topic, partition)

                status = if offset < lo_offset
                  :expired
                elsif offset > hi_offset
                  :future
                else
                  :ok
                end

                result[topic][partition] = {
                  offset: offset,
                  lo_offset: lo_offset,
                  hi_offset: hi_offset,
                  status: status
                }
              end
            end
          end

          result
        end

        # Compares committed offsets between two consumer groups. Reads offsets for both groups
        # from the __consumer_offsets log and reports any differences.
        #
        # Use this after calling {#migrate_consumer_group} or {#migrate_consumer_groups} to
        # confirm the target group received all offsets correctly. A :mismatch status with
        # detailed differences helps pinpoint which topic-partitions need attention before
        # switching consumers to the new group.
        #
        # @param source_group [String] source consumer group
        # @param target_group [String] target consumer group
        # @param lookback_ms [Integer] how far back to start scanning in ms
        # @return [Hash{Symbol => Object}] verification result with :status, :source_offsets,
        #   :target_offsets, and :mismatches keys
        #
        # @example Verify migration succeeded
        #   Karafka::Admin::Recovery.verify_migration('sync', 'sync_v2')
        #   #=> { status: :ok, source_offsets: {...}, target_offsets: {...}, mismatches: [] }
        #
        # @example Full migrate-and-verify workflow
        #   Karafka::Admin::Recovery.migrate_consumer_group('sync', 'sync_v2')
        #   result = Karafka::Admin::Recovery.verify_migration('sync', 'sync_v2')
        #   raise "Migration failed: #{result[:mismatches]}" unless result[:status] == :ok
        def verify_migration(source_group, target_group, lookback_ms: DEFAULT_LOOKBACK_MS)
          source_offsets = read_committed_offsets(source_group, lookback_ms: lookback_ms)
          target_offsets = read_committed_offsets(target_group, lookback_ms: lookback_ms)

          mismatches = []

          source_offsets.each do |topic, partitions|
            partitions.each do |partition, source_offset|
              target_offset = target_offsets.dig(topic, partition)

              next if target_offset == source_offset

              mismatches << {
                topic: topic,
                partition: partition,
                source_offset: source_offset,
                target_offset: target_offset
              }
            end
          end

          status = mismatches.empty? ? :ok : :mismatch

          {
            status: status,
            source_offsets: source_offsets,
            target_offsets: target_offsets,
            mismatches: mismatches
          }
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
