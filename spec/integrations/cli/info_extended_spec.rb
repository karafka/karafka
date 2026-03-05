# frozen_string_literal: true

# Karafka CLI info --extended should print routing, config, and kafka config details

setup_karafka

draw_routes(create_topics: false) do
  consumer_group :integration_group do
    topic :integration_topic do
      consumer Class.new(Karafka::BaseConsumer)
      dead_letter_queue(topic: "dlq_target", max_retries: 3)
    end
  end
end

ARGV[0] = "info"
ARGV[1] = "--extended"

results = capture_stdout do
  Karafka::Cli.start
end

# Verify routing section is present
assert results.include?("Routing")
assert results.include?("Consumer group: integration_group")
assert results.include?("Topic: integration_topic")
assert results.include?("Subscription group:")
assert results.include?("max_messages:")
assert results.include?("max_wait_time:")
assert results.include?("initial_offset:")

# Verify feature detection works
assert results.include?("dead_letter_queue:")

# Verify config section is present
assert results.include?("Config")
assert results.include?("client_id:")
assert results.include?("concurrency:")
assert results.include?("shutdown_timeout:")
assert results.include?("pause_timeout:")
assert results.include?("strict_topics_namespacing:")

# Verify kafka config section is present
assert results.include?("Kafka Config")
