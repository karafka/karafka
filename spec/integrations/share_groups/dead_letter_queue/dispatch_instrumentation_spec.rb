# frozen_string_literal: true

# Share group (KIP-932) dead letter queue should emit the `dead_letter_queue.dispatched` event with
# the dispatched message and its consumer for every record moved to the DLQ topic.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    raise StandardError
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:events] << [event[:message].raw_payload, event[:caller].class, event[:caller].topic.name]
end

elements = DT.uuids(10)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[:events].size >= 10
end

assert_equal elements.sort, DT[:events].map(&:first).sort
assert_equal [[Consumer, DT.topics[0]]], DT[:events].map { |event| event[1..] }.uniq
