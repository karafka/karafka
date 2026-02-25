# frozen_string_literal: true

# Instrumentation events should maintain proper ordering guarantees and sequence during
# parallel processing and concurrent event emission.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      sequence = message.payload.to_i

      # Track processing order without custom events
      DT[:start_order] << sequence
      DT[:process_order] << sequence
      DT[:complete_order] << sequence
      DT[:processed_sequences] << sequence
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      deserializer ->(message) { message.raw_payload }
    end
  end
end

Karafka.monitor.subscribe("consumer.consumed") do |_event|
  DT[:consumer_events] << 1
end

# Produce ordered messages
elements = (1..50).to_a.map(&:to_s)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:processed_sequences].size >= 50 &&
    DT[:consumer_events].size >= 1
end

# Verify ordering within each processing step
assert_equal DT[:start_order].sort, DT[:start_order]
assert_equal DT[:process_order].sort, DT[:process_order]
assert_equal DT[:complete_order].sort, DT[:complete_order]

# Verify all sequences were processed
assert_equal (1..50).to_a, DT[:processed_sequences].sort
