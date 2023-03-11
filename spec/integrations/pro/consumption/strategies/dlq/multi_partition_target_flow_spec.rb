# frozen_string_literal: true

# When handling failing messages from a single partition and there are many errors, enhanced DLQ
# will provide strong ordering warranties inside DLQ.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message.partition
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end

  topic DT.topics[1] do
    config(partitions: 10)
    consumer DlqConsumer
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:broken].count >= 20
end

assert_equal 1, DT[:broken].uniq.count
