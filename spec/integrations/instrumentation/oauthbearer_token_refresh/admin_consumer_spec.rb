# frozen_string_literal: true

# When OAUTHBEARER is used, librdkafka should request a token when a Karafka::Admin consumer
# starts and Karafka should deliver it to the listener with this consumer as the bearer.
# Once the consumer is closed, its callback should be unbound, so a later refresh request with its
# name should no longer reach the listener.
#
# The test broker has no SASL listener, so we do not run any operation against it.

class Listener
  def on_oauthbearer_token_refresh(event)
    DT[:bearers] << event[:bearer]
  end
end

setup_karafka do |config|
  config.kafka[:"security.protocol"] = "sasl_plaintext"
  config.kafka[:"sasl.mechanisms"] = "OAUTHBEARER"
  config.oauth.token_provider_listener = Listener.new
end

callbacks = Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks
name = nil

Karafka::Admin.with_consumer do |consumer|
  sleep(0.01) until DT[:bearers].size >= 1

  name = consumer.wrapped.name

  assert consumer.wrapped.equal?(DT[:bearers].first)

  # Same request as the one librdkafka sends, to prove the callback is bound while in use
  callbacks.call(nil, name)

  assert_equal 2, DT[:bearers].size
end

callbacks.call(nil, name)

assert_equal 2, DT[:bearers].size
assert DT[:bearers].first.is_a?(Rdkafka::Consumer)
