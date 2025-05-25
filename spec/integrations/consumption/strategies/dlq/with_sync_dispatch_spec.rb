# frozen_string_literal: true

# When using DLQ, it should work when dispatch in sync

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 0

      DT[:offsets] << message.offset

      mark_as_consumed message
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message.offset
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 2,
      dispatch_method: :produce_sync
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(5)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:offsets].uniq.size > 1
end

assert_equal DT[:offsets], (1..4).to_a
