# frozen_string_literal: true

# Verify that the new global pause configuration API works correctly

setup_karafka do |config|
  # Use the new nested API to configure
  config.pause.timeout = 2_000
  config.pause.max_timeout = 8_000
  config.pause.with_exponential_backoff = true
end

# ========== Test new API returns correct values ==========
assert_equal 2_000, Karafka::App.config.pause.timeout
assert_equal 8_000, Karafka::App.config.pause.max_timeout
assert_equal true, Karafka::App.config.pause.with_exponential_backoff

# ========== Test backwards compatibility - old accessors still work ==========
assert_equal 2_000, Karafka::App.config.pause_timeout
assert_equal 8_000, Karafka::App.config.pause_max_timeout
assert_equal true, Karafka::App.config.pause_with_exponential_backoff

# ========== Test both APIs are synchronized ==========
assert_equal Karafka::App.config.pause.timeout, Karafka::App.config.pause_timeout
assert_equal Karafka::App.config.pause.max_timeout, Karafka::App.config.pause_max_timeout
assert_equal(
  Karafka::App.config.pause.with_exponential_backoff,
  Karafka::App.config.pause_with_exponential_backoff
)
