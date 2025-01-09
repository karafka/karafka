# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
        # @param consumer [::Rdkafka::Consumer] consumer instance needed to talk with Kafka
        # @param expanded_topics [Hash] hash with expanded and normalized topics data
        def initialize(consumer, expanded_topics)
          @consumer = ::Karafka::Connection::Proxy.new(consumer)
          @expanded_topics = expanded_topics
          @mapped_topics = Hash.new { |h, k| h[k] = {} }
        end

        # @return [Rdkafka::Consumer::TopicPartitionList] final tpl we can use to subscribe
        def call
          resolve_partitions_without_offsets
          resolve_partitions_with_exact_offsets
          resolve_partitions_with_negative_offsets
          resolve_partitions_with_time_offsets
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
            @mapped_topics[name] = partitions.map { |partition| [partition, 0] }.to_h
          end
        end

        # If we get exact numeric offsets, we can just start from them without any extra work
        def resolve_partitions_with_exact_offsets
          @expanded_topics.each do |name, partitions|
            next unless partitions.is_a?(Hash)

            partitions.each do |partition, offset|
              # Skip negative and time based offsets
              next unless offset.is_a?(Integer) && offset >= 0

              # Exact offsets can be used as they are
              # No need for extra operations
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
          @expanded_topics.each do |name, partitions|
            next unless partitions.is_a?(Hash)

            partitions.each do |partition, offset|
              # Care only about numerical offsets
              #
              # For time based we already resolve them via librdkafka lookup API
              next unless offset.is_a?(Integer)

              low_offset, high_offset = @consumer.query_watermark_offsets(name, partition)

              # Care only about negative offsets (last n messages)
              #
              # We reject the above results but we **NEED** to run the `#query_watermark_offsets`
              # for each topic partition nonetheless. Without this, librdkafka fetches a lot more
              # metadata about each topic and each partition and this takes much more time than
              # just getting watermarks. If we do not run watermark, at least an extra second
              # is added at the beginning of iterator flow
              #
              # This may not be significant when this runs in the background but in case of
              # using iterator in thins like Puma, it heavily impacts the end user experience
              next unless offset.negative?

              # We add because this offset is negative
              @mapped_topics[name][partition] = [high_offset + offset, low_offset].max
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
