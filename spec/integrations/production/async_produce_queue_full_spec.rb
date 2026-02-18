# frozen_string_literal: true

# This spec tests the behavior of produce_async when the producer's internal queue is full.
#
# Real-world scenario: Messages to an unknown/unreachable topic pile up in the queue
# (can't be delivered), eventually filling the queue. When full, subsequent produce_async
# calls raise immediately with WaterDrop::Errors::ProduceError.
#
# Key insight: This is different from unknown topic errors - queue full is a resource
# exhaustion issue that manifests as an immediate exception.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"allow.auto.create.topics"] = false
end

# Create a producer with a tiny queue to trigger queue-full quickly
tiny_queue_producer = WaterDrop::Producer.new do |config|
  config.kafka = {
    "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092"),
    # Set very small queue to trigger queue-full error quickly
    "queue.buffering.max.messages": 10,
    "queue.buffering.max.kbytes": 1,
    "allow.auto.create.topics": false,
    # Disable retries so messages stay in queue longer
    "message.send.max.retries": 0,
    "message.timeout.ms": 30_000,
    # Don't send immediately, buffer them
    "linger.ms": 10_000
  }
end

# Non-existent topic - messages will pile up in the queue
unknown_topic = "queue-full-test-#{SecureRandom.uuid}"

DT[:immediate_errors] = []
DT[:queued_successfully] = []

# Flood the queue with large messages to hit the kbyte limit quickly
large_payload = "X" * 500

100.times do |i|
  tiny_queue_producer.produce_async(
    topic: unknown_topic,
    payload: "#{large_payload}-#{i}"
  )
  DT[:queued_successfully] << i
rescue WaterDrop::Errors::ProduceError => e
  DT[:immediate_errors] << {
    attempt: i,
    error: e,
    message: e.message,
    cause: e.cause&.class&.name
  }
  break
end

tiny_queue_producer.close

# Assertions

# We should have queued some messages successfully before the queue filled
assert DT[:queued_successfully].size >= 1, "Should queue at least 1 message before queue filled"

# produce_async should raise immediately when queue is full
assert DT[:immediate_errors].any?, "produce_async should raise immediately when queue is full"

queue_full_error = DT[:immediate_errors].first[:error]

assert !queue_full_error.nil?, "Should have captured the queue full error"

# The error should mention queue full
error_message = queue_full_error.message.downcase
assert error_message.include?("queue") || error_message.include?("full"), "Error should mention queue"
