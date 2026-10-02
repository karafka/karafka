# frozen_string_literal: true

# Share group (KIP-932) dead letter queue with synchronous dispatch: a record that keeps failing is
# moved to the DLQ topic (confirmed before it is rejected) once it was delivered more than
# `max_retries` times. It is not delivered again and the rest of the topic is consumed.

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
      dead_letter_queue(topic: DT.topics[1], max_retries: 2, dispatch_method: :produce_sync)
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(10)
produce_many(DT.topics[0], elements.first(5) + ["poison"] + elements.last(5))

start_karafka_and_wait_until do
  if DT[:dispatched].size >= 1 && DT[:accepted].uniq.size >= 10
    DT[:dispatched_at] = Time.now unless DT.key?(:dispatched_at)

    # Make sure the broker does not deliver it again
    Time.now - DT[:dispatched_at] > 5
  else
    false
  end
end

assert_equal [1, 2, 3], DT[:poison]
assert_equal ["poison"], DT[:dispatched]
assert_equal ["poison"], Karafka::Admin.read_topic(DT.topics[1], 0, 10).map(&:raw_payload)
assert_equal elements.sort, DT[:accepted].uniq.sort
