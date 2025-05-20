# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    class Iterator
      # There are various ways you can provide topics information for iterating.
      #
      # This mapper normalizes this data, resolves offsets and maps the time based offsets into
      # appropriate once
      #
      # Following formats are accepted:
      #
      # - 'topic1' - just a string with one topic name
      # - ['topic1', 'topic2'] - just the names
      # - { 'topic1' => -100 } - names with negative lookup offset
      # - { 'topic1' => { 0 => 5 } } - names with exact partitions offsets
      # - { 'topic1' => { 0 => -5 }, 'topic2' => { 1 => 5 } } - with per partition negative offsets
      # - { 'topic1' => 100 } - means we run all partitions from the offset 100
      # - { 'topic1' => Time.now - 60 } - we run all partitions from the message from 60s ago
      # - { 'topic1' => { 1 => Time.now - 60 } } - partition1 from message 60s ago
      # - { 'topic1' => { 1 => true } } - will pick first offset on this CG for partition 1
      # - { 'topic1' => true } - will pick first offset for all partitions
      # - { 'topic1' => :earliest } - will pick earliest offset for all partitions
      # - { 'topic1' => :latest } - will pick latest (high-watermark) for all partitions
      class Expander
        # Expands topics to which we want to subscribe with partitions information in case this
        # info is not provided.
        #
        # @param topics [Array, Hash, String] topics definitions
        # @return [Hash] expanded and normalized requested topics and partitions data
        def call(topics)
          expanded = Hash.new { |h, k| h[k] = {} }

          normalize_format(topics).map do |topic, details|
            if details.is_a?(Hash)
              details.each do |partition, offset|
                expanded[topic][partition] = offset
              end
            else
              partition_count(topic).times do |partition|
                # If no offsets are provided, we just start from zero
                expanded[topic][partition] = details || 0
              end
            end
          end

          expanded
        end

        private

        # Input can be provided in multiple formats. Here we normalize it to one (hash).
        #
        # @param topics [Array, Hash, String] requested topics
        # @return [Hash] normalized hash with topics data
        def normalize_format(topics)
          # Simplification for the single topic case
          topics = [topics] if topics.is_a?(String)

          # If we've got just array with topics, we need to convert that into a representation
          # that we can expand with offsets
          topics = topics.map { |name| [name, false] }.to_h if topics.is_a?(Array)
          # We remap by creating new hash, just in case the hash came as the argument for this
          # expanded. We do not want to modify user provided hash
          topics.transform_keys(&:to_s)
        end

        # List of topics with their partition information for expansion
        # We cache it so we do not have to run consecutive requests to obtain data about multiple
        # topics
        def topics
          @topics ||= Admin.cluster_info.topics
        end

        # @param name [String] topic name
        # @return [Integer] number of partitions of the topic we want to iterate over
        def partition_count(name)
          topics
            .find { |topic| topic.fetch(:topic_name) == name }
            .tap { |topic| topic || raise(Errors::TopicNotFoundError, name) }
            .fetch(:partitions)
            .size
        end
      end
    end
  end
end
