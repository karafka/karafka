# frozen_string_literal: true

# Share group (KIP-932) dead letter queue with `topic: false`: a record that keeps failing is
# rejected once it was delivered more than `max_retries` times, without dispatching it anywhere.
# It is not delivered again and the rest of the topic is consumed.

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
    topic DT.topic do
      consumer Consumer
      dead_letter_queue(topic: false, max_retries: 1)
    end
  end
end

setup_share_group

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(10)
produce_many(DT.topic, elements.first(5) + ["poison"] + elements.last(5))

start_karafka_and_wait_until do
  if DT[:poison].size >= 2 && DT[:accepted].uniq.size >= 10
    DT[:rejected_at] = Time.now unless DT.key?(:rejected_at)

    # Make sure the broker does not deliver it again
    Time.now - DT[:rejected_at] > 5
  else
    false
  end
end

assert_equal [1, 2], DT[:poison]
assert_equal [], DT[:dispatched]
assert_equal elements.sort, DT[:accepted].uniq.sort
