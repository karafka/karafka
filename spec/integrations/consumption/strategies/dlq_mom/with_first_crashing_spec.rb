# frozen_string_literal: true

# When its the first message ever that is constantly crashing it should move as expected with the
# DLQ flow

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset

      raise StandardError
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
    dead_letter_queue(topic: DT.topics[1], max_retries: 2)
    manual_offset_management true
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

assert_equal [0, 1], DT[:offsets].uniq
