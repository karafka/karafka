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
      # Topics in the cluster with their partition counts
      class Topics < Read
        action_name "topics"
        description "Topics in the cluster with their partition counts, sorted by name"
        sources :broker

        arg :pattern, type: :regexp, description: "Regular expression topic names must match"
        paginated

        # @param pattern [String, nil] regular expression topic names must match
        # @param page [Integer, nil] page number
        # @param per_page [Integer, nil] page size
        # @return [Base::Page] topics page
        def call(pattern: nil, page: nil, per_page: nil)
          matcher = pattern && Regexp.new(pattern)

          topics = admin.cluster_info.topics.filter_map do |topic|
            next if matcher && !matcher.match?(topic[:topic_name])

            {
              topic: topic[:topic_name],
              partition_count: topic[:partition_count]
            }
          end

          topics.sort_by! { |topic| topic[:topic] }

          paginate(topics, page: page, per_page: per_page)
        end
      end
    end
  end
end
