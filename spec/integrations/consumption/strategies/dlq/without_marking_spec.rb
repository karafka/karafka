# frozen_string_literal: true

# When using DLQ without post error marking, the committed offset should remain unchanged

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
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
      max_retries: 1,
      mark_after_dispatch: false
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(5)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:broken].size >= 3
end

assert_equal fetch_next_offset, 0
