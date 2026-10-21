# frozen_string_literal: true

# Share group (KIP-932) dead letter queue works when records are accepted synchronously: the
# healthy records are confirmed by the broker (`#mark_as_accepted!` returns true) and are never
# delivered again, while the failing one is moved to the DLQ after its retries.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.raw_payload == DT[:broken]

      DT[:accepted] << message.raw_payload
      DT[:results] << mark_as_accepted!(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 2)
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(5)
DT[:broken] = elements[4]
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[:dispatched].any? && DT[:accepted].size >= 4 && sleep(2)
end

assert_equal elements[0..3].sort, DT[:accepted].sort
assert_equal [true], DT[:results].uniq
assert_equal [elements[4]], DT[:dispatched]
assert_equal [elements[4]], Karafka::Admin.read_topic(DT.topics[1], 0, 10).map(&:raw_payload)
