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
      # Groups and topics from the application routing, with consumers and their source location
      class Routing < Read
        action_name "routing"
        description(
          "Routed groups, subscription groups and topics with consumer classes and their " \
          "source location"
        )
        sources :routing

        # @return [Array<Hash>] routed topics
        def call
          Karafka::App.routes.flat_map do |group|
            group.subscription_groups.flat_map do |subscription_group|
              subscription_group.topics.map do |topic|
                {
                  group_id: group.id,
                  group_type: group.group_type.to_s,
                  subscription_group_id: subscription_group.id,
                  topic: topic.name,
                  active: topic.active?,
                  consumer: topic.consumer&.name,
                  source_location: source_location(topic.consumer)
                }
              end
            end
          end
        end

        private

        # @param consumer [Class, nil] consumer class
        # @return [Hash, nil] path and line where the consumer class is defined
        def source_location(consumer)
          return nil unless consumer&.name

          path, line = Object.const_source_location(consumer.name)

          return nil unless path

          root = "#{Karafka.root}/"

          {
            path: path.start_with?(root) ? path.delete_prefix(root) : path,
            line: line
          }
        end
      end
    end
  end
end
