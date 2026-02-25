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

# Verify that both old and new pause configuration styles work and are bidirectionally compatible

setup_karafka

draw_routes(create_topics: false) do
  # Topic A: configured using new pause() method
  topic :a do
    consumer Class.new(Karafka::BaseConsumer)
    pause(
      timeout: 1_500,
      max_timeout: 6_000,
      with_exponential_backoff: true
    )
  end

  # Topic B: configured using old direct setters
  topic :b do
    consumer Class.new(Karafka::BaseConsumer)
    pause_timeout 3_000
    pause_max_timeout 9_000
    pause_with_exponential_backoff false
  end

  # Topic C: uses defaults (no explicit configuration)
  topic :c do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

topics = Karafka::App.routes.first.topics

# ========== Test Topic A: pause() method ==========
topic_a = topics[0]

# Verify new API works
assert_equal 1_500, topic_a.pausing.timeout
assert_equal 6_000, topic_a.pausing.max_timeout
assert_equal true, topic_a.pausing.with_exponential_backoff
assert_equal true, topic_a.pausing.with_exponential_backoff?
assert_equal true, topic_a.pausing.active?

# Verify backwards compatibility - old accessors reflect new config
assert_equal 1_500, topic_a.pause_timeout
assert_equal 6_000, topic_a.pause_max_timeout
assert_equal true, topic_a.pause_with_exponential_backoff

# ========== Test Topic B: old setters ==========
topic_b = topics[1]

# Verify old accessors work
assert_equal 3_000, topic_b.pause_timeout
assert_equal 9_000, topic_b.pause_max_timeout
assert_equal false, topic_b.pause_with_exponential_backoff

# Verify new API reflects old config
# Note: when using old setters, active? will be false until pause() is called
assert_equal 3_000, topic_b.pausing.timeout
assert_equal 9_000, topic_b.pausing.max_timeout
assert_equal false, topic_b.pausing.with_exponential_backoff
assert_equal false, topic_b.pausing.with_exponential_backoff?
# With old setters, pausing is not explicitly active
assert_equal false, topic_b.pausing.active?

# ========== Test Topic C: defaults ==========
topic_c = topics[2]

# Verify defaults through old API
assert_equal 1, topic_c.pause_timeout
assert_equal 1, topic_c.pause_max_timeout
assert_equal false, topic_c.pause_with_exponential_backoff

# Verify defaults through new API
assert_equal 1, topic_c.pausing.timeout
assert_equal 1, topic_c.pausing.max_timeout
assert_equal false, topic_c.pausing.with_exponential_backoff
assert_equal false, topic_c.pausing.with_exponential_backoff?
assert_equal false, topic_c.pausing.active?

# ========== Test bidirectional updates (Topic A) ==========
# Calling pause() again should update values and old accessors should reflect it
topic_a.pause(timeout: 2_000)

assert_equal 2_000, topic_a.pausing.timeout
assert_equal 2_000, topic_a.pause_timeout # old accessor reflects new value

# ========== Test serialization includes both formats ==========
topic_a_hash = topic_a.to_h

# Old format (backwards compatibility)
assert_equal 2_000, topic_a_hash[:pause_timeout]
assert_equal 6_000, topic_a_hash[:pause_max_timeout]
assert_equal true, topic_a_hash[:pause_with_exponential_backoff]

# New format
assert topic_a_hash.key?(:pausing)
assert_equal 2_000, topic_a_hash[:pausing][:timeout]
assert_equal 6_000, topic_a_hash[:pausing][:max_timeout]
assert_equal true, topic_a_hash[:pausing][:with_exponential_backoff]
assert_equal true, topic_a_hash[:pausing][:active]
