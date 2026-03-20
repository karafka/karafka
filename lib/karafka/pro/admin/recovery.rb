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
      # Provides coordinator-bypass offset reading and blast-radius assessment for scenarios
      # where the Kafka group coordinator is in a FAILED state and normal admin APIs return
      # NOT_COORDINATOR or time out.
      #
      # Works for any coordinator failure scenario:
      #   - KAFKA-19862 (compaction race during coordinator load)
      #   - Broker OOM / GC pause making coordinator unreachable
      #   - Network partition isolating the coordinator broker
      #   - Any future bug that transitions a coordinator shard to FAILED
      #
      # Each consumer group is assigned to a specific __consumer_offsets partition (and therefore
      # a specific coordinator broker) based on its name. When that coordinator enters a FAILED
      # state, all operations for the group - joins, heartbeats, offset commits, and offset
      # fetches - are stuck until the coordinator recovers.
      #
      # A common recovery strategy is migrating to a new consumer group with a different name,
      # which causes Kafka to hash it to a (likely) different __consumer_offsets partition served
      # by a healthy coordinator. This class provides the tools to:
      #   1. Read committed offsets directly from the raw __consumer_offsets log (bypassing the
      #      broken coordinator) via {#read_committed_offsets}
      #   2. Assess blast radius: which broker coordinates a group ({#coordinator_for}), which
      #      partitions a broker leads ({#affected_partitions}), and which groups are affected
      #      ({#affected_groups})
      #
      # To complete the migration, use {Karafka::Admin::ConsumerGroups.seek} to write the
      # recovered offsets to the new group.
      #
      # All reads go through the fetch API and never touch the group coordinator.
      #
      # @note These methods should NOT be used unless you are experiencing issues that require
      #   manual intervention. Misuse can lead to data loss or other problems.
      class Recovery < Karafka::Admin
        # Internal topic where Kafka stores committed offsets and group metadata
        OFFSETS_TOPIC = "__consumer_offsets"

        # Default lookback window for offset scanning (1 hour). Covers any normal commit interval.
        # Provide an earlier Time if your group commits infrequently or the incident has been
        # ongoing for longer than 1 hour.
        DEFAULT_START_TIME_OFFSET = 3_600

        private_constant :OFFSETS_TOPIC, :DEFAULT_START_TIME_OFFSET

        class << self
          # @param consumer_group_id [String] consumer group to read offsets for
          # @param start_time [Time] how far back to start scanning (default: 1 hour ago)
          # @return [Hash{String => Hash{Integer => Integer}}]
          # @see #read_committed_offsets
          def read_committed_offsets(
            consumer_group_id,
            start_time: Time.now - DEFAULT_START_TIME_OFFSET
          )
            new.read_committed_offsets(consumer_group_id, start_time: start_time)
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
          # @param start_time [Time] how far back to start scanning (default: 1 hour ago)
          # @return [Array<String>] sorted consumer group names
          # @see #affected_groups
          def affected_groups(partition, start_time: Time.now - DEFAULT_START_TIME_OFFSET)
            new.affected_groups(partition, start_time: start_time)
          end

          # @param broker_id [Integer] broker node id
          # @return [Array<Integer>] sorted partition numbers
          # @see #affected_partitions
          def affected_partitions(broker_id)
            new.affected_partitions(broker_id)
          end
        end

        # Reads committed offsets for a consumer group directly from the __consumer_offsets internal
        # topic, bypassing the group coordinator. Only scans the single __consumer_offsets partition
        # that holds data for the given group (determined by Java's String#hashCode mod partition
        # count), starting from start_time and reading forward to EOF. Later records overwrite
        # earlier ones so the result always reflects the most recent committed offset per partition.
        #
        # @note All consumers in this group should be fully stopped before calling this method.
        #   While normally they would already be stopped due to a coordinator failure, if the
        #   cluster recovers concurrently, active consumers may commit newer offsets that this scan
        #   will not capture, resulting in stale data.
        #
        # @note This method may take a noticeable amount of time to complete because it scans
        #   the raw __consumer_offsets log from start_time forward to the end. The duration depends
        #   on the volume of offset commits in the scan window across all consumer groups that hash
        #   to the same __consumer_offsets partition.
        #
        # @note The result only contains topic-partitions that had offsets committed after
        #   start_time. If a partition never had an offset committed, or if the commit happened
        #   before start_time, it will be absent from the result. It is the caller's responsibility
        #   to verify that all expected topic-partitions are present before using the result for
        #   migration or other operations.
        #
        # @param consumer_group_id [String] consumer group to read offsets for
        # @param start_time [Time] how far back to start scanning (default: 1 hour ago)
        # @return [Hash{String => Hash{Integer => Integer}}]
        #   { topic => { partition => committed_offset } }
        #
        # @example Read offsets for the last hour (default)
        #   Karafka::Admin::Recovery.read_committed_offsets('sync')
        #   #=> { 'events' => { 0 => 1400, 1 => 1402, ... } }
        #
        # @example Read offsets for the last 6 hours
        #   Karafka::Admin::Recovery.read_committed_offsets('sync', start_time: Time.now - 6 * 3600)
        #
        # @example Read offsets from a specific point in time
        #   Karafka::Admin::Recovery.read_committed_offsets('sync', start_time: Time.new(2025, 3, 1))
        #
        # @example Migrate a stuck consumer group to a new name (two-step workflow)
        #   # Step 1: Read committed offsets from the broken group (bypasses coordinator)
        #   offsets = Karafka::Admin::Recovery.read_committed_offsets('sync')
        #   #=> { 'events' => { 0 => 1400, 1 => 1402 }, 'orders' => { 0 => 890 } }
        #
        #   # Step 2: Inspect the recovered offsets — verify all expected topics and partitions
        #   # are present and the offset values look reasonable before committing them
        #
        #   # Step 3: Write the offsets to the target group using standard Admin APIs
        #   Karafka::Admin::ConsumerGroups.seek('sync_v2', offsets)
        #
        #   # Now reconfigure your consumers to use 'sync_v2' and restart them
        def read_committed_offsets(
          consumer_group_id,
          start_time: Time.now - DEFAULT_START_TIME_OFFSET
        )
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

            if parsed[:offset].nil?
              # Tombstone — offset was deleted, remove from results
              committed[parsed[:topic]].delete(parsed[:partition])
              committed.delete(parsed[:topic]) if committed[parsed[:topic]].empty?
            else
              # Last write wins — scanning forward means we naturally end up with the most
              # recent commit per partition
              committed[parsed[:topic]][parsed[:partition]] = parsed[:offset]
            end
          end

          committed.sort.to_h.transform_values { |parts| parts.sort.to_h }
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
              Errors::MetadataError,
              "Could not retrieve metadata for '#{OFFSETS_TOPIC}'"
            )
          end

          partitions = offsets_topic[:partitions]
          partition_info = partitions.find { |p| p[:partition_id] == target_partition }

          unless partition_info
            raise(
              Errors::MetadataError,
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
              Errors::MetadataError,
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

        # Scans a __consumer_offsets partition and returns consumer group names that have active
        # committed offsets. Groups where all offsets have been tombstoned (deleted) within the
        # scan window are excluded.
        #
        # Use this to discover which consumer groups are affected when a coordinator broker fails.
        # Combined with {#affected_partitions}, this gives the full blast radius of a broker
        # outage: first find which __consumer_offsets partitions the failed broker leads, then
        # scan each partition to discover all affected consumer groups.
        #
        # @param partition [Integer] __consumer_offsets partition to scan
        # @param start_time [Time] how far back to start scanning (default: 1 hour ago)
        # @return [Array<String>] sorted list of consumer group names with active offsets
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
        def affected_groups(partition, start_time: Time.now - DEFAULT_START_TIME_OFFSET)
          count = offsets_partition_count

          unless partition >= 0 && partition < count
            raise(
              Errors::PartitionOutOfRangeError,
              "Partition #{partition} is out of range (0...#{count})"
            )
          end

          # Track offsets per group with last-write-wins so fully tombstoned groups
          # (all offsets deleted) are excluded from the result
          committed = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }

          iterator = Pro::Iterator.new(
            { OFFSETS_TOPIC => { partition => start_time } },
            settings: @custom_kafka
          )

          iterator.each do |message|
            next unless message.raw_key

            parsed = parse_offset_commit(message)
            next unless parsed

            group = parsed[:group]

            if parsed[:offset].nil?
              committed[group][parsed[:topic]].delete(parsed[:partition])
              committed[group].delete(parsed[:topic]) if committed[group][parsed[:topic]].empty?
            else
              committed[group][parsed[:topic]][parsed[:partition]] = parsed[:offset]
            end
          end

          committed.select { |_, topics| !topics.empty? }.keys.sort
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
              Errors::MetadataError,
              "Could not retrieve metadata for '#{OFFSETS_TOPIC}'"
            )
          end

          offsets_topic[:partitions]
            .select { |p| p[:leader] == broker_id }
            .map { |p| p[:partition_id] }
            .sort
        end

        private

        # Parses a raw __consumer_offsets message into structured offset commit data.
        # Handles both v0 and v1 offset commit key formats (both use the same layout for
        # group/topic/partition). Tombstone records (nil payload) indicate offset deletion and
        # are returned with offset: nil so callers can remove stale entries.
        #
        # @param message [Karafka::Messages::Message] raw message from __consumer_offsets
        # @return [Hash, nil] parsed offset commit or nil if not an offset commit record.
        #   When the record is a tombstone (deletion), the :offset value will be nil.
        def parse_offset_commit(message)
          return nil unless message.raw_key

          key = message.raw_key.b
          key_version = key[0, 2].unpack1("n")

          # Versions 0 and 1 are offset commit records with identical key layout
          return nil unless key_version <= 1

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

          # Tombstone (nil payload) means the offset was deleted
          unless message.raw_payload
            return { group: group, topic: topic, partition: partition, offset: nil }
          end

          val = message.raw_payload.b

          # value layout: int16 version | int64 offset | ...
          offset = val[2, 8].unpack1("q>")

          { group: group, topic: topic, partition: partition, offset: offset }
        end

        # Computes Java's String#hashCode for a given string. Java hashes UTF-16 code units
        # (char values), not raw bytes. For ASCII-only strings this is identical to byte-level
        # hashing, but non-ASCII characters (accented letters, CJK, emoji) require encoding to
        # UTF-16 and hashing each 16-bit code unit (including surrogate pairs for characters
        # above U+FFFF).
        #
        # @param str [String] input string
        # @return [Integer] signed 32-bit hash value matching Java's String#hashCode
        def java_hash_code(str)
          hash = 0

          # Encode to UTF-16BE to get Java's char sequence, then hash each 16-bit code unit
          str.encode("UTF-16BE").bytes.each_slice(2) do |hi, lo|
            code_unit = (hi << 8) | lo
            hash = (hash * 31 + code_unit) & 0xFFFFFFFF
          end

          # Convert unsigned 32-bit to signed 32-bit (Java int semantics)
          (hash >= 0x80000000) ? hash - 0x100000000 : hash
        end

        # Returns the partition count of the __consumer_offsets topic. Memoized per instance since
        # this value never changes at runtime.
        #
        # @return [Integer] number of partitions
        # @raise [Errors::MetadataError] when topic metadata cannot be retrieved
        def offsets_partition_count
          @offsets_partition_count ||= begin
            topic_info = cluster_info.topics.find do |t|
              t[:topic_name] == OFFSETS_TOPIC
            end

            unless topic_info
              raise(
                Errors::MetadataError,
                "Could not retrieve partition count for '#{OFFSETS_TOPIC}'"
              )
            end

            topic_info[:partition_count]
          end
        end
      end
    end
  end
end

# We alias this for Pro users so we don't end up having two Admin namespaces from the end
# user perspective. This enhances the UX.
Karafka::Admin::Recovery = Karafka::Pro::Admin::Recovery
