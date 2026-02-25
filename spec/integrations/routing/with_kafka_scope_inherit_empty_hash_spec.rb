# frozen_string_literal: true

# Test that kafka scope settings with inherit: true properly merge defaults even when
# empty hash is provided as config. This addresses the edge case where calling
# kafka(**{}) with inherit: true should still preserve the defaults from
# Karafka::App.config.kafka instead of overriding them.

setup_karafka

# Add some custom defaults to test inheritance behavior
Karafka::App.config.kafka[:"session.timeout.ms"] = 30_000
Karafka::App.config.kafka[:"request.timeout.ms"] = 60_000

# First test that without inherit, empty config fails validation (no bootstrap.servers)
failed = false

begin
  draw_routes(create_topics: false) do
    topic "topic_without_inherit_empty" do
      consumer Class.new
      kafka(**{}) # Empty config without inherit should fail
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed

Karafka::App.routes.clear

# Now test the working cases with inherit
draw_routes(create_topics: false) do
  # Topic with inherit: true and empty hash config should preserve defaults
  topic "topic_with_empty_config" do
    consumer Class.new
    kafka(**{}, inherit: true)
  end

  # Topic with inherit: true and some specific config should merge with defaults
  topic "topic_with_specific_config" do
    consumer Class.new
    kafka("enable.partition.eof": true, inherit: true)
  end
end

cgs = Karafka::App.consumer_groups
topic_with_empty = cgs.first.subscription_groups.find do |sg|
  sg.topics.any? { |t| t.name == "topic_with_empty_config" }
end.topics.find("topic_with_empty_config")

topic_with_specific = cgs.first.subscription_groups.find do |sg|
  sg.topics.any? { |t| t.name == "topic_with_specific_config" }
end.topics.find("topic_with_specific_config")

# Test that empty hash with inherit: true preserves defaults
assert_equal 30_000, topic_with_empty.kafka[:"session.timeout.ms"]
assert_equal 60_000, topic_with_empty.kafka[:"request.timeout.ms"]
assert_equal "127.0.0.1:9092", topic_with_empty.kafka[:"bootstrap.servers"]

# Test that specific config with inherit: true merges with defaults
assert_equal 30_000, topic_with_specific.kafka[:"session.timeout.ms"]
assert_equal 60_000, topic_with_specific.kafka[:"request.timeout.ms"]
assert_equal "127.0.0.1:9092", topic_with_specific.kafka[:"bootstrap.servers"]
assert_equal true, topic_with_specific.kafka[:"enable.partition.eof"]
