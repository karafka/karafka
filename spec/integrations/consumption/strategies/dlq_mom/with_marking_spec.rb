# frozen_string_literal: true

# When we do mark and user does not mark, we will not end up with an infinite loop.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 6
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 10

      DT[:offsets] << message.offset

      mark_as_consumed(message)
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << [message.offset, message.raw_payload]
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 1,
      # The below one is set to false by default for MOM
      mark_after_dispatch: true
    )
    manual_offset_management(true)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
    manual_offset_management(true)
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "consumer.consume.error"

  DT[:errors] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:offsets].uniq.size >= 99
end

# The skipped one should have never been processed
assert !DT[:offsets].include?(10)

# Offsets should have been committed
assert_equal 100, fetch_next_offset
