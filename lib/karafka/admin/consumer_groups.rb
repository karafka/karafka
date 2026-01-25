# frozen_string_literal: true

module Karafka
  class Admin
    # Consumer group administration operations
    # Provides methods to manage Kafka consumer groups including offset management, migration, and
    # introspection
    class ConsumerGroups < Admin
      # 2010-01-01 00:00:00 - way before Kafka was released so no messages should exist prior to
      # this date
      # We do not use the explicit -2 librdkafka value here because we resolve this offset without
      # consuming data
      LONG_TIME_AGO = Time.at(1_262_300_400)

      # one day in seconds for future time reference
      DAY_IN_SECONDS = 60 * 60 * 24

      private_constant :LONG_TIME_AGO, :DAY_IN_SECONDS

      class << self
        # @param consumer_group_id [String] consumer group for which we want to move offsets
        # @param topics_with_partitions_and_offsets [Hash] hash with topics and settings
        # @see #seek
        def seek(consumer_group_id, topics_with_partitions_and_offsets)
          new.seek(consumer_group_id, topics_with_partitions_and_offsets)
        end

        # @param previous_name [String] old consumer group name
        # @param new_name [String] new consumer group name
        # @param topics [Array<String>] topics for which we want to copy offsets
        # @see #copy
        def copy(previous_name, new_name, topics)
          new.copy(previous_name, new_name, topics)
        end

        # @param previous_name [String] old consumer group name
        # @param new_name [String] new consumer group name
        # @param topics [Array<String>] topics for which we want to migrate offsets
        # @param delete_previous [Boolean] should we delete previous consumer group after rename
        # @see #rename
        def rename(previous_name, new_name, topics, delete_previous: true)
          new.rename(previous_name, new_name, topics, delete_previous: delete_previous)
        end

        # @param consumer_group_id [String] consumer group name
        # @see #delete
        def delete(consumer_group_id)
          new.delete(consumer_group_id)
        end

        # @param consumer_group_id [String] consumer group id to trigger rebalance for
        # @see #trigger_rebalance
        def trigger_rebalance(consumer_group_id)
          new.trigger_rebalance(consumer_group_id)
        end

        # @param consumer_groups_with_topics [Hash{String => Array<String>}] hash with consumer
        #   groups names with array of topics
        # @param active_topics_only [Boolean] if set to false, will select also inactive topics
        # @see #read_lags_with_offsets
        def read_lags_with_offsets(consumer_groups_with_topics = {}, active_topics_only: true)
          new.read_lags_with_offsets(
            consumer_groups_with_topics,
            active_topics_only: active_topics_only
          )
        end
      end

      # Moves the offset on a given consumer group and provided topic to the requested location
      #
      # @param consumer_group_id [String] id of the consumer group for which we want to move the
      #   existing offset
      # @param topics_with_partitions_and_offsets [Hash] Hash with list of topics and settings to
      #   where to move given consumer. It allows us to move particular partitions or whole
      #   topics if we want to reset all partitions to for example a point in time.
      #
      # @return [void]
      #
      # @note This method should **not** be executed on a running consumer group as it creates a
      #   "fake" consumer and uses it to move offsets.
      #
      # @example Move a single topic partition nr 1 offset to 100
      #   Karafka::Admin::ConsumerGroups.seek('group-id', { 'topic' => { 1 => 100 } })
      #
      # @example Move offsets on all partitions of a topic to 100
      #   Karafka::Admin::ConsumerGroups.seek('group-id', { 'topic' => 100 })
      #
      # @example Move offset to 5 seconds ago on partition 2
      #   Karafka::Admin::ConsumerGroups.seek('group-id', { 'topic' => { 2 => 5.seconds.ago } })
      #
      # @example Move to the earliest offset on all the partitions of a topic
      #   Karafka::Admin::ConsumerGroups.seek('group-id', { 'topic' => 'earliest' })
      #
      # @example Move to the latest (high-watermark) offset on all the partitions of a topic
      #   Karafka::Admin::ConsumerGroups.seek('group-id', { 'topic' => 'latest' })
      #
      # @example Move offset of a single partition to earliest
      #   Karafka::Admin::ConsumerGroups.seek('group-id', { 'topic' => { 1 => 'earliest' } })
      #
      # @example Move offset of a single partition to latest
      #   Karafka::Admin::ConsumerGroups.seek('group-id', { 'topic' => { 1 => 'latest' } })
      def seek(consumer_group_id, topics_with_partitions_and_offsets)
        tpl_base = {}

        # Normalize the data so we always have all partitions and topics in the same format
        # That is in a format where we have topics and all partitions with their per partition
        # assigned offsets
        topics_with_partitions_and_offsets.each do |topic, partitions_with_offsets|
          tpl_base[topic] = {}

          if partitions_with_offsets.is_a?(Hash)
            tpl_base[topic] = partitions_with_offsets
          else
            topic_info = Topics.new(kafka: @custom_kafka).info(topic)
            topic_info[:partition_count].times do |partition|
              tpl_base[topic][partition] = partitions_with_offsets
            end
          end
        end

        tpl_base.each_value do |partitions|
          partitions.transform_values! do |position|
            # Support both symbol and string based references
            casted_position = position.is_a?(Symbol) ? position.to_s : position

            # This remap allows us to transform some special cases in a reference that can be
            # understood by Kafka
            case casted_position
            # Earliest is not always 0. When compacting/deleting it can be much later, that's why
            # we fetch the oldest possible offset
            # false is treated the same as 'earliest'
            when "earliest", false
              LONG_TIME_AGO
            # Latest will always be the high-watermark offset and we can get it just by getting
            # a future position
            when "latest"
              Time.now + DAY_IN_SECONDS
            # Regular offset case
            else
              position
            end
          end
        end

        tpl = Rdkafka::Consumer::TopicPartitionList.new
        # In case of time based location, we need to to a pre-resolution, that's why we keep it
        # separately
        time_tpl = Rdkafka::Consumer::TopicPartitionList.new

        # Distribute properly the offset type
        tpl_base.each do |topic, partitions_with_offsets|
          partitions_with_offsets.each do |partition, offset|
            target = offset.is_a?(Time) ? time_tpl : tpl
            # We reverse and uniq to make sure that potentially duplicated references are removed
            # in such a way that the newest stays
            target.to_h[topic] ||= []
            target.to_h[topic] << Rdkafka::Consumer::Partition.new(partition, offset)
            target.to_h[topic].reverse!
            target.to_h[topic].uniq!(&:partition)
            target.to_h[topic].reverse!
          end
        end

        settings = { "group.id": consumer_group_id }

        with_consumer(settings) do |consumer|
          # If we have any time based stuff to resolve, we need to do it prior to commits
          unless time_tpl.empty?
            real_offsets = consumer.offsets_for_times(time_tpl)

            real_offsets.to_h.each do |name, results|
              results.each do |result|
                raise(Errors::InvalidTimeBasedOffsetError) unless result

                partition = result.partition

                # Negative offset means we're beyond last message and we need to query for the
                # high watermark offset to get the most recent offset and move there
                if result.offset.negative?
                  _, offset = consumer.query_watermark_offsets(name, result.partition)
                else
                  # If we get an offset, it means there existed a message close to this time
                  # location
                  offset = result.offset
                end

                # Since now we have proper offsets, we can add this to the final tpl for commit
                tpl.to_h[name] ||= []
                tpl.to_h[name] << Rdkafka::Consumer::Partition.new(partition, offset)
                tpl.to_h[name].reverse!
                tpl.to_h[name].uniq!(&:partition)
                tpl.to_h[name].reverse!
              end
            end
          end

          consumer.commit_offsets(tpl, async: false)
        end
      end

      # Takes consumer group and its topics and copies all the offsets to a new named group
      #
      # @param previous_name [String] old consumer group name
      # @param new_name [String] new consumer group name
      # @param topics [Array<String>] topics for which we want to migrate offsets during rename
      #
      # @return [Boolean] true if anything was migrated, otherwise false
      #
      # @note This method should **not** be executed on a running consumer group as it creates a
      #   "fake" consumer and uses it to move offsets.
      #
      # @note If new consumer group exists, old offsets will be added to it.
      def copy(previous_name, new_name, topics)
        remap = Hash.new { |h, k| h[k] = {} }

        old_lags = read_lags_with_offsets({ previous_name => topics })

        return false if old_lags.empty?
        return false if old_lags.values.all? { |topic_data| topic_data.values.all?(&:empty?) }

        read_lags_with_offsets({ previous_name => topics })
          .fetch(previous_name)
          .each do |topic, partitions|
            partitions.each do |partition_id, details|
              offset = details[:offset]

              # No offset on this partition
              next if offset.negative?

              remap[topic][partition_id] = offset
            end
          end

        seek(new_name, remap)

        true
      end

      # Takes consumer group and its topics and migrates all the offsets to a new named group
      #
      # @param previous_name [String] old consumer group name
      # @param new_name [String] new consumer group name
      # @param topics [Array<String>] topics for which we want to migrate offsets during rename
      # @param delete_previous [Boolean] should we delete previous consumer group after rename.
      #   Defaults to true.
      #
      # @return [Boolean] true if rename (and optionally removal) was ok or false if there was
      #   nothing really to rename
      #
      # @note This method should **not** be executed on a running consumer group as it creates a
      #   "fake" consumer and uses it to move offsets.
      #
      # @note After migration unless `delete_previous` is set to `false`, old group will be
      #   removed.
      #
      # @note If new consumer group exists, old offsets will be added to it.
      def rename(previous_name, new_name, topics, delete_previous: true)
        copy_result = copy(previous_name, new_name, topics)

        return false unless copy_result
        return copy_result unless delete_previous

        delete(previous_name)

        true
      end

      # Removes given consumer group (if exists)
      #
      # @param consumer_group_id [String] consumer group name
      #
      # @return [void]
      #
      # @note This method should not be used on a running consumer group as it will not yield any
      #   results.
      def delete(consumer_group_id)
        with_admin do |admin|
          handler = admin.delete_group(consumer_group_id)
          handler.wait(max_wait_timeout: max_wait_time_seconds)
        end
      end

      # Triggers a rebalance for the specified consumer group by briefly joining and leaving
      #
      # @param consumer_group_id [String] consumer group id to trigger rebalance for
      #
      # @return [void]
      #
      # @raise [Karafka::Errors::InvalidConfigurationError] when consumer group is not found in
      #   routing or has no topics
      #
      # @note This method creates a temporary "fake" consumer that joins the consumer group,
      #   triggering a rebalance when it joins and another when it leaves. This should only be
      #   used for operational/testing purposes as it causes two rebalances.
      #
      # @note The consumer group does not need to be running for this to work, but if it is,
      #   it will experience rebalances.
      #
      # @note The behavior follows the configured rebalance protocol. For cooperative sticky
      #   rebalancing or KIP-848 based protocols, there may be no immediate reaction to the
      #   rebalance trigger as these protocols allow incremental partition reassignments without
      #   stopping all consumers.
      #
      # @note Topics are always detected from the routing configuration. The consumer settings
      #   (kafka config) are taken from the first topic in the consumer group to ensure
      #   consistency with the actual consumer configuration.
      #
      # @example Trigger rebalance for a consumer group
      #   Karafka::Admin::ConsumerGroups.trigger_rebalance('my-group')
      def trigger_rebalance(consumer_group_id)
        consumer_group = Karafka::App.routes.find { |cg| cg.id == consumer_group_id }

        unless consumer_group
          raise(
            Errors::InvalidConfigurationError,
            "Consumer group '#{consumer_group_id}' not found in routing"
          )
        end

        topics = consumer_group.topics.map(&:name)

        if topics.empty?
          raise(
            Errors::InvalidConfigurationError,
            "Consumer group '#{consumer_group_id}' has no topics"
          )
        end

        # Get the first topic to extract kafka settings
        first_topic = consumer_group.topics.first

        # Build consumer settings using the consumer group's kafka config from first topic
        # This ensures we use the same settings as the actual consumers
        # Following the same pattern as in Karafka::Connection::Client#build_kafka
        consumer_settings = Setup::AttributesMap.consumer(first_topic.kafka.dup)
        consumer_settings[:"group.id"] = consumer_group.id
        consumer_settings[:"enable.auto.offset.store"] = false
        consumer_settings[:"auto.offset.reset"] ||= first_topic.initial_offset

        with_consumer(consumer_settings) do |consumer|
          # Subscribe to the topics - this triggers the first rebalance
          consumer.subscribe(*topics)

          # Wait briefly (100ms) to allow the rebalance to initiate
          # The actual rebalance happens asynchronously, so we just need to give it a moment
          sleep(0.1)

          # Unsubscribe - this will trigger the second rebalance when the consumer closes
          # The ensure block in with_consumer will handle the unsubscribe and close
        end
      end

      # Reads lags and offsets for given topics in the context of consumer groups defined in the
      #   routing
      #
      # @param consumer_groups_with_topics [Hash{String => Array<String>}] hash with consumer
      #   groups names with array of topics to query per consumer group inside
      # @param active_topics_only [Boolean] if set to false, when we use routing topics, will
      #   select also topics that are marked as inactive in routing
      #
      # @return [Hash{String => Hash{Integer => Hash{Integer => Object}}}] hash where the top
      #   level keys are the consumer groups and values are hashes with topics and inside
      #   partitions with lags and offsets
      #
      # @note For topics that do not exist, topic details will be set to an empty hash
      #
      # @note For topics that exist but were never consumed by a given CG we set `-1` as lag and
      #   the offset on each of the partitions that were not consumed.
      #
      # @note This lag reporting is for committed lags and is "Kafka-centric", meaning that this
      #   represents lags from Kafka perspective and not the consumer. They may differ.
      def read_lags_with_offsets(consumer_groups_with_topics = {}, active_topics_only: true)
        # We first fetch all the topics with partitions count that exist in the cluster so we
        # do not query for topics that do not exist and so we can get partitions count for all
        # the topics we may need. The non-existent and not consumed will be filled at the end
        existing_topics = cluster_info.topics.to_h do |topic|
          [topic[:topic_name], topic[:partition_count]]
        end.freeze

        # If no expected CGs, we use all from routing that have active topics
        if consumer_groups_with_topics.empty?
          consumer_groups_with_topics = Karafka::App.routes.to_h do |cg|
            cg_topics = cg.topics.select do |cg_topic|
              active_topics_only ? cg_topic.active? : true
            end

            [cg.id, cg_topics.map(&:name)]
          end
        end

        # We make a copy because we will remove once with non-existing topics
        # We keep original requested consumer groups with topics for later backfilling
        cgs_with_topics = consumer_groups_with_topics.dup
        cgs_with_topics.transform_values!(&:dup)

        # We can query only topics that do exist, this is why we are cleaning those that do not
        # exist
        cgs_with_topics.each_value do |requested_topics|
          requested_topics.delete_if { |topic| !existing_topics.include?(topic) }
        end

        groups_lags = Hash.new { |h, k| h[k] = {} }
        groups_offs = Hash.new { |h, k| h[k] = {} }

        cgs_with_topics.each do |cg, topics|
          # Do not add to tpl topics that do not exist
          next if topics.empty?

          tpl = Rdkafka::Consumer::TopicPartitionList.new

          with_consumer("group.id": cg) do |consumer|
            topics.each { |topic| tpl.add_topic(topic, existing_topics[topic]) }

            commit_offsets = consumer.committed(tpl)

            commit_offsets.to_h.each do |topic, partitions|
              groups_offs[cg][topic] = {}

              partitions.each do |partition|
                # -1 when no offset is stored
                groups_offs[cg][topic][partition.partition] = partition.offset || -1
              end
            end

            consumer.lag(commit_offsets).each do |topic, partitions_lags|
              groups_lags[cg][topic] = partitions_lags
            end
          end
        end

        consumer_groups_with_topics.each do |cg, topics|
          groups_lags[cg]

          topics.each do |topic|
            groups_lags[cg][topic] ||= {}

            next unless existing_topics.key?(topic)

            # We backfill because there is a case where our consumer group would consume for
            # example only one partition out of 20, rest needs to get -1
            existing_topics[topic].times do |partition_id|
              groups_lags[cg][topic][partition_id] ||= -1
            end
          end
        end

        merged = Hash.new { |h, k| h[k] = {} }

        groups_lags.each do |cg, topics|
          topics.each do |topic, partitions|
            merged[cg][topic] = {}

            partitions.each do |partition, lag|
              merged[cg][topic][partition] = {
                offset: groups_offs.fetch(cg).fetch(topic).fetch(partition),
                lag: lag
              }
            end
          end
        end

        merged
      end
    end
  end
end
