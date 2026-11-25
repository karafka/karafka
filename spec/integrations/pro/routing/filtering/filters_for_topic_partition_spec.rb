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

# Filters built from the routing filtering config for a topic partition should be the same as the
# ones Karafka uses when consuming, including the built-in filters that need the topic and partition

setup_karafka

draw_routes(create_topics: false) do
  consumer_group DT.group do
    parallel_segments(count: 2, partitioner: ->(message) { message.key })

    topic DT.topic do
      consumer Class.new(Karafka::BaseConsumer)
      inline_insights(required: true)
      expire_in(1_000)
      filter(->(topic, partition) { [topic.name, partition] })
    end
  end
end

topic = Karafka::App.routes.first.topics.first
filters = topic.filtering.filters(topic, 1)
filters_scope = Karafka::Pro::Processing::ConsumerGroups::Filters

assert_equal 4, filters.size
assert filters[0].is_a?(Karafka::Pro::Processing::ConsumerGroups::ParallelSegments::Filters::Default)
assert filters[1].is_a?(filters_scope::InlineInsightsDelayer)
assert filters[2].is_a?(filters_scope::Expirer)
assert_equal [DT.topic, 1], filters[3]
