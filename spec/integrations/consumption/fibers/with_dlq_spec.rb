# frozen_string_literal: true

# When running the fibers workers backend, non-recoverable messages should be moved to the DLQ
# the same way as with the threads backend

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset.zero?

      DT[:offsets] << message.offset

      mark_as_consumed message
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message.raw_payload
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 2)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(20)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[:offsets].uniq.size >= 19 && DT.key?(:broken)
end

# The broken (first) message was dispatched to the DLQ and the rest was consumed
assert_equal [elements.first], DT[:broken].uniq
assert_equal (1..19).to_a, DT[:offsets].uniq.sort
