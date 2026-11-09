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
    module Actions
      # Partitions with their watermarks and the configuration of a single topic
      class Topic < Read
        action_name "topic"
        description "Partitions (leaders, replicas, watermarks) and configuration of a topic"
        sources :broker

        arg :topic_name, type: :string, description: "Name of the topic", required: true

        # Value we use instead of the value of a sensitive configuration
        REDACTED = "[REDACTED]"

        private_constant :REDACTED

        # @param topic_name [String] name of the topic
        # @return [Hash] topic details
        def call(topic_name:)
          # Cluster metadata is used because a single topic metadata request may create the topic
          info = admin.cluster_info.topics.find { |topic| topic[:topic_name] == topic_name }

          raise(Errors::NotFoundError, topic_name) unless info

          partition_ids = info[:partitions].map { |partition| partition[:partition_id] }
          watermarks = admin.read_watermark_offsets({ topic_name => partition_ids })[topic_name]

          {
            topic: topic_name,
            partition_count: info[:partition_count],
            partitions: info[:partitions].map do |partition|
              low, high = watermarks.fetch(partition[:partition_id])

              {
                partition: partition[:partition_id],
                leader: partition[:leader],
                replicas: partition[:replicas],
                in_sync_replicas: partition[:isrs],
                low_watermark: low,
                high_watermark: high
              }
            end,
            configs: admin.describe_topic_configs(topic_name).map do |config|
              {
                name: config.name,
                value: redact?(config) ? REDACTED : config.value,
                default: config.default?,
                read_only: config.read_only?,
                sensitive: config.sensitive?
              }
            end
          }
        end

        private

        # @param config [Karafka::Admin::Configs::Config] topic config
        # @return [Boolean] should the value be hidden
        def redact?(config)
          config.sensitive? || Karafka::Cli::Info::SENSITIVE_KAFKA_CONFIG_PATTERN.match?(config.name)
        end
      end
    end
  end
end
