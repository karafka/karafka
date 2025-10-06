# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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

# Verify the pausing config object
assert topic_a.pausing.is_a?(Karafka::Pro::Routing::Features::Pausing::Config)
assert_equal true, topic_a.pausing.active?
assert_equal 2_000, topic_a.pausing.timeout
assert_equal 8_000, topic_a.pausing.max_timeout
assert_equal true, topic_a.pausing.with_exponential_backoff
assert_equal true, topic_a.pausing.with_exponential_backoff?

# Verify pausing? predicate
assert_equal true, topic_a.pausing?

# Verify backwards compatibility - old accessors still work
assert_equal 2_000, topic_a.pause_timeout
assert_equal 8_000, topic_a.pause_max_timeout
assert_equal true, topic_a.pause_with_exponential_backoff

# Verify to_h includes pausing config
topic_a_hash = topic_a.to_h
assert topic_a_hash.key?(:pausing)
assert_equal true, topic_a_hash[:pausing][:active]
assert_equal 2_000, topic_a_hash[:pausing][:timeout]
assert_equal 8_000, topic_a_hash[:pausing][:max_timeout]
assert_equal true, topic_a_hash[:pausing][:with_exponential_backoff]

# Test topic B - with defaults (no pause config)
topic_b = topics[1]

# Verify the pausing config object exists with defaults
assert topic_b.pausing.is_a?(Karafka::Pro::Routing::Features::Pausing::Config)
assert_equal false, topic_b.pausing.active?
assert_equal 1, topic_b.pausing.timeout
assert_equal 1, topic_b.pausing.max_timeout
assert_equal false, topic_b.pausing.with_exponential_backoff
assert_equal false, topic_b.pausing.with_exponential_backoff?

# Verify pausing? predicate for not configured topic
assert_equal false, topic_b.pausing?

# Verify backwards compatibility for defaults
assert_equal 1, topic_b.pause_timeout
assert_equal 1, topic_b.pause_max_timeout
assert_equal false, topic_b.pause_with_exponential_backoff
