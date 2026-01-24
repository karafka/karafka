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

# When altering the default pausing, it should not impact other topics

setup_karafka

draw_routes(create_topics: false) do
  topic :a do
    consumer Class.new(Karafka::BaseConsumer)
    pause(
      timeout: 1_000,
      max_timeout: 5_000,
      with_exponential_backoff: true
    )
  end

  topic :b do
    consumer Class.new(Karafka::BaseConsumer)
    pause(
      timeout: 5_000,
      max_timeout: 10_000,
      with_exponential_backoff: false
    )
  end

  topic :c do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

topics = Karafka::App.routes.first.topics

assert_equal 1_000, topics[0].pause_timeout
assert_equal 5_000, topics[0].pause_max_timeout
assert_equal true, topics[0].pause_with_exponential_backoff

assert_equal 5_000, topics[1].pause_timeout
assert_equal 10_000, topics[1].pause_max_timeout
assert_equal false, topics[1].pause_with_exponential_backoff

assert_equal 1, topics[2].pause_timeout
assert_equal 1, topics[2].pause_max_timeout
assert_equal false, topics[2].pause_with_exponential_backoff
