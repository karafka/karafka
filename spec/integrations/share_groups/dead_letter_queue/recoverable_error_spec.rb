# frozen_string_literal: true

# Share group (KIP-932) dead letter queue should not dispatch a record that fails once and then
# recovers on its redelivery before reaching `max_retries`. It is just retried and accepted.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      if message.raw_payload == DT[:recoverable] && !DT.key?(:done)
        DT[:done] = true
        raise StandardError
      end

      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
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

Karafka.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "consumer.consume.error"

  DT[:errors] << 1
end

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(100)
DT[:recoverable] = elements[10]
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 100
end

assert_equal 1, DT[:errors].size
assert_equal elements.sort, DT[:accepted].uniq.sort
assert_equal 0, DT[:dispatched].size
assert_equal [], Karafka::Admin.read_topic(DT.topics[1], 0, 10)
