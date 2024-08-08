# frozen_string_literal: true

# Karafka should propagate the oauth listener to the producer when oauth in use

class Listener
  def on_oauthbearer_token_refresh(_); end
end

LISTENER = Listener.new

Karafka::App.setup do |config|
  config.kafka = { 'bootstrap.servers': 'host:9092' }
  config.oauth.token_provider_listener = LISTENER
end

assert_equal(Karafka::App.config.oauth.token_provider_listener, LISTENER)
assert_equal(Karafka.producer.config.oauth.token_provider_listener, LISTENER)
