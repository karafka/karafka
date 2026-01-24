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

# Proper segment names and ids should be generated

setup_karafka

draw_routes(create_topics: false) do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 2,
      partitioner: ->(message) { message.key }
    )

    topic DT.topic do
      consumer Karafka::BaseConsumer
    end
  end
end

assert_equal 2, Karafka::App.routes.size
assert_equal 0, Karafka::App.routes.first.segment_id
assert_equal 1, Karafka::App.routes.last.segment_id

Karafka::App.routes.clear

draw_routes(create_topics: false) do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Karafka::BaseConsumer
    end
  end
end

assert_equal(1, Karafka::App.routes.size)
assert_equal(-1, Karafka::App.routes.first.segment_id)

Karafka::App.routes.clear
