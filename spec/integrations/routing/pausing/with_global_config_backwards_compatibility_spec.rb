# frozen_string_literal: true

# Verify that both old and new global pause configuration APIs work and are bidirectionally
# compatible

setup_karafka do |config|
  # Use the new nested API to configure
  config.pause.timeout = 1_500
  config.pause.max_timeout = 6_000
  config.pause.with_exponential_backoff = true
end

assert_equal 1_500, Karafka::App.config.pause.timeout
assert_equal 6_000, Karafka::App.config.pause.max_timeout
assert_equal true, Karafka::App.config.pause.with_exponential_backoff

assert_equal 1_500, Karafka::App.config.pause_timeout
assert_equal 6_000, Karafka::App.config.pause_max_timeout
assert_equal true, Karafka::App.config.pause_with_exponential_backoff

assert_equal Karafka::App.config.pause.timeout, Karafka::App.config.pause_timeout
assert_equal Karafka::App.config.pause.max_timeout, Karafka::App.config.pause_max_timeout
assert_equal(
  Karafka::App.config.pause.with_exponential_backoff,
  Karafka::App.config.pause_with_exponential_backoff
)

Karafka::App.config.pause_timeout = 2_000
assert_equal 2_000, Karafka::App.config.pause.timeout
assert_equal 2_000, Karafka::App.config.pause_timeout

Karafka::App.config.pause_max_timeout = 8_000
assert_equal 8_000, Karafka::App.config.pause.max_timeout
assert_equal 8_000, Karafka::App.config.pause_max_timeout

Karafka::App.config.pause_with_exponential_backoff = false
assert_equal false, Karafka::App.config.pause.with_exponential_backoff
assert_equal false, Karafka::App.config.pause_with_exponential_backoff

Karafka::App.config.pause.timeout = 3_000
assert_equal 3_000, Karafka::App.config.pause_timeout
assert_equal 3_000, Karafka::App.config.pause.timeout

Karafka::App.config.pause.max_timeout = 10_000
assert_equal 10_000, Karafka::App.config.pause_max_timeout
assert_equal 10_000, Karafka::App.config.pause.max_timeout

Karafka::App.config.pause.with_exponential_backoff = true
assert_equal true, Karafka::App.config.pause_with_exponential_backoff
assert_equal true, Karafka::App.config.pause.with_exponential_backoff
