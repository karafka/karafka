# frozen_string_literal: true

# Share group (KIP-932) dead letter queue with `max_retries` not lower than the group
# `share.delivery.count.limit` (3 vs 2): the broker drops the failing record at its limit before
# Karafka gets to dispatch it, so nothing reaches the DLQ topic. `max_retries` has to stay below
# the group delivery count limit for the DLQ to work.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    poison = false

    messages.each do |message|
      if message.raw_payload == "poison"
        poison = true
        DT[:poison] << message.delivery_count
      else
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      end
    end

    raise StandardError if poison
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 3)
    end
  end
end

setup_share_group(DT.topics[0], configs: { "share.delivery.count.limit" => "2" })
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(10)
produce_many(DT.topics[0], elements.first(5) + ["poison"] + elements.last(5))

start_karafka_and_wait_until do
  if DT[:poison].size >= 2 && DT[:accepted].uniq.size >= 10
    DT[:exhausted_at] = Time.now unless DT.key?(:exhausted_at)

    # Make sure the broker does not deliver it again after the limit
    Time.now - DT[:exhausted_at] > 5
  else
    false
  end
end

assert_equal [1, 2], DT[:poison]
assert_equal [], DT[:dispatched]
assert_equal [], Karafka::Admin.read_topic(DT.topics[1], 0, 10)
assert_equal elements.sort, DT[:accepted].uniq.sort
