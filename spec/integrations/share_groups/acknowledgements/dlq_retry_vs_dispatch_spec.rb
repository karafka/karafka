# frozen_string_literal: true

# Share group (KIP-932) dead letter queue with `max_retries: 1`: a record that fails once is
# released, succeeds on its second delivery and is not dispatched, while a record that fails on
# both deliveries is dispatched to the DLQ topic and not delivered again.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    failed = false

    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]

      if message.raw_payload == "poison" || (message.raw_payload == "flaky" && message.delivery_count == 1)
        failed = true
      else
        DT[:accepted] << [message.raw_payload, message.delivery_count]
        mark_as_accepted(message)
      end
    end

    raise StandardError if failed
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(4)
produce_many(DT.topics[0], elements.first(2) + %w[flaky poison] + elements.last(2))

start_karafka_and_wait_until do
  if DT[:dispatched].size >= 1 && DT[:accepted].map(&:first).uniq.size >= 5
    DT[:dispatched_at] = Time.now unless DT.key?(:dispatched_at)

    # Make sure the broker does not deliver anything again
    Time.now - DT[:dispatched_at] > 5
  else
    false
  end
end

def deliveries(payload)
  DT[:deliveries].select { |name, _| name == payload }.map(&:last)
end

assert_equal [1, 2], deliveries("flaky")
assert_equal [1, 2], deliveries("poison")
assert DT[:accepted].include?(["flaky", 2])
assert_equal ["poison"], DT[:dispatched]
assert_equal ["poison"], Karafka::Admin.read_topic(DT.topics[1], 0, 10).map(&:raw_payload)
assert_equal (elements + ["flaky"]).sort, DT[:accepted].map(&:first).uniq.sort
