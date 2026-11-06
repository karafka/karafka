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
      # Facade exposing only the reading part of `Karafka::Admin`. Read actions get this
      # instead of `Karafka::Admin`, so they cannot change the cluster state.
      class ReadOnlyAdmin
        # @return [Hash] cluster id, controller and brokers
        def describe_cluster
          Karafka::Admin.describe_cluster
        end

        # @return [Rdkafka::Metadata] cluster metadata info
        def cluster_info
          Karafka::Admin.cluster_info
        end

        # @param topics_with_partitions [Hash{String => Array<Integer>}] topics with partitions
        # @return [Hash{String => Hash{Integer => Array<Integer>}}] low and high watermarks
        def read_watermark_offsets(topics_with_partitions)
          Karafka::Admin.read_watermark_offsets(topics_with_partitions)
        end

        # @param topic_name [String] name of the topic
        # @return [Array<Karafka::Admin::Configs::Config>] topic configs
        def describe_topic_configs(topic_name)
          resource = Karafka::Admin::Configs::Resource.new(type: :topic, name: topic_name)

          Karafka::Admin::Configs.describe(resource).first.configs
        end

        # @param groups_with_topics [Hash{String => Array<String>}] consumer groups with topics
        # @return [Hash] lags and offsets per consumer group, topic and partition
        def read_lags_with_offsets(groups_with_topics = {})
          Karafka::Admin.read_lags_with_offsets(groups_with_topics, active_topics_only: false)
        end
      end
    end
  end
end
