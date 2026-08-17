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

# Verify that the new pausing config object approach works correctly

setup_karafka

draw_routes(create_topics: false) do
  topic :a do
    consumer Class.new(Karafka::BaseConsumer)
    pause(
      timeout: 2_000,
      max_timeout: 8_000,
      with_exponential_backoff: true
    )
  end

  topic :b do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

topics = Karafka::App.routes.first.topics

# Test topic A - with custom pausing config
topic_a = topics[0]

# Verify the pause config object
assert topic_a.pause.is_a?(Karafka::Pro::Routing::Features::Pausing::Config)
assert_equal true, topic_a.pause.active?
assert_equal 2_000, topic_a.pause.timeout
assert_equal 8_000, topic_a.pause.max_timeout
assert_equal true, topic_a.pause.with_exponential_backoff
assert_equal true, topic_a.pause.with_exponential_backoff?

# Verify pause? predicate
assert_equal true, topic_a.pause?

# Verify to_h includes pause config
topic_a_hash = topic_a.to_h
assert topic_a_hash.key?(:pause)
assert_equal true, topic_a_hash[:pause][:active]
assert_equal 2_000, topic_a_hash[:pause][:timeout]
assert_equal 8_000, topic_a_hash[:pause][:max_timeout]
assert_equal true, topic_a_hash[:pause][:with_exponential_backoff]

# Test topic B - with defaults (no pause config)
topic_b = topics[1]

# Verify the pause config object exists with defaults
assert topic_b.pause.is_a?(Karafka::Pro::Routing::Features::Pausing::Config)
assert_equal false, topic_b.pause.active?
assert_equal 1, topic_b.pause.timeout
assert_equal 1, topic_b.pause.max_timeout
assert_equal false, topic_b.pause.with_exponential_backoff
assert_equal false, topic_b.pause.with_exponential_backoff?

# Verify pause? predicate for not configured topic
assert_equal false, topic_b.pause?
