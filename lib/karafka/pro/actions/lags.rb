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
      # Committed offsets and lags of consumer groups, per topic and partition
      class Lags < Read
        action_name "lags"
        description(
          "Committed offset and lag per consumer group, topic and partition " \
          "(-1 when nothing was committed). Defaults to the routed consumer groups"
        )
        sources :broker

        arg :consumer_group_id, type: :string, description: "Consumer group id"
        arg :topic_name, type: :string, description: "Topic name"
        paginated

        # @param consumer_group_id [String, nil] consumer group to limit results to
        # @param topic_name [String, nil] topic to limit results to
        # @param page [Integer, nil] page number
        # @param per_page [Integer, nil] page size
        # @return [Base::Page] lags page
        def call(consumer_group_id: nil, topic_name: nil, page: nil, per_page: nil)
          groups = groups_with_topics(consumer_group_id, topic_name)

          # Admin reads all the routed consumer groups when given none, so we must not ask
          # when the filters match nothing
          return paginate([], page: page, per_page: per_page) if groups.empty?

          lags = admin.read_lags_with_offsets(groups)
          rows = []

          lags.each do |group_id, topics|
            topics.each do |topic, partitions|
              partitions.each do |partition, details|
                rows << {
                  consumer_group_id: group_id,
                  topic: topic,
                  partition: partition,
                  offset_committed: details[:offset],
                  lag_committed: details[:lag]
                }
              end
            end
          end

          rows.sort_by! { |row| row.values_at(:consumer_group_id, :topic, :partition) }

          paginate(rows, page: page, per_page: per_page)
        end

        private

        # @param consumer_group_id [String, nil] consumer group to limit results to
        # @param topic_name [String, nil] topic to limit results to
        # @return [Hash{String => Array<String>}] consumer groups with topics to check
        def groups_with_topics(consumer_group_id, topic_name)
          routed = Karafka::App.routes.consumer_groups.to_h do |group|
            [group.id, group.topics.map(&:name)]
          end

          routed.select! { |group_id, _| group_id == consumer_group_id } if consumer_group_id
          routed[consumer_group_id] = [topic_name] if consumer_group_id && topic_name
          routed.transform_values! { |topics| topics & [topic_name] } if topic_name
          routed.reject { |_, topics| topics.empty? }
        end
      end
    end
  end
end
