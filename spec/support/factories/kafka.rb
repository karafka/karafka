# frozen_string_literal: true

# Mimics Rdkafka::Consumer::Message structure for testing
# We use a Struct instead of the actual Rdkafka::Consumer::Message class because:
# - Rdkafka::Consumer::Message has a complex C-extension based constructor that doesn't accept
#   keyword arguments and requires internal rdkafka handles
# - Using a Struct allows easy test object creation with FactoryBot
# - The Struct provides the same interface (attribute accessors) needed by our code
KafkaFetchedMessage = Struct.new(
  :payload,
  :key,
  :offset,
  :timestamp,
  :topic,
  :partition,
  :headers,
  keyword_init: true
)

FactoryBot.define do
  factory :kafka_fetched_message, class: "KafkaFetchedMessage" do
    payload { rand.to_s }
    key { nil }
    offset { 0 }
    timestamp { Time.now }
    topic { rand.to_s }
    partition { 0 }
    headers { {} }

    skip_create

    initialize_with { new(**attributes) }
  end
end
