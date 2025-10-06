# frozen_string_literal: true

# Verify that the old global pause configuration API (setters) still works correctly
# This is a backwards compatibility test

setup_karafka do |config|
  # Use the old flat API to configure
  config.pause_timeout = 2_000
  config.pause_max_timeout = 8_000
  config.pause_with_exponential_backoff = true
end

# ========== Test old API returns correct values ==========
assert_equal 2_000, Karafka::App.config.pause_timeout
assert_equal 8_000, Karafka::App.config.pause_max_timeout
assert_equal true, Karafka::App.config.pause_with_exponential_backoff

# ========== Test new API reflects old config ==========
assert_equal 2_000, Karafka::App.config.pause.timeout
assert_equal 8_000, Karafka::App.config.pause.max_timeout
assert_equal true, Karafka::App.config.pause.with_exponential_backoff

# ========== Test both APIs are synchronized ==========
assert_equal Karafka::App.config.pause_timeout, Karafka::App.config.pause.timeout
assert_equal Karafka::App.config.pause_max_timeout, Karafka::App.config.pause.max_timeout
assert_equal(
  Karafka::App.config.pause_with_exponential_backoff,
  Karafka::App.config.pause.with_exponential_backoff
)
