# frozen_string_literal: true

# After a successful dispatch to DLQ, next first attempt should not have errors in the tracker

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:tracker] << errors_tracker.size if attempt == 1

    raise StandardError
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 2)
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:tracker].size >= 2
end

assert_equal DT[:tracker].uniq, [0]
