# frozen_string_literal: true

# Karafka should not propagate a nil oauth listener to the producer

Karafka::App.setup do |config|
  config.kafka = { "bootstrap.servers": "host:9092" }
  config.oauth.token_provider_listener = nil
end

assert_equal(nil, Karafka::App.config.oauth.token_provider_listener)
assert_equal(false, Karafka.producer.config.oauth.token_provider_listener)
