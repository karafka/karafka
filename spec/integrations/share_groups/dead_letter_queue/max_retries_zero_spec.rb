# frozen_string_literal: true

# Share group (KIP-932) dead letter queue with `max_retries: 0`: a failing record is moved to the
# DLQ topic right after its first failed delivery.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| DT[:deliveries] << message.delivery_count }

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
  DT[:dispatched] << event[:message].raw_payload
end

produce(DT.topics[0], "failing")

start_karafka_and_wait_until do
  if DT[:dispatched].size >= 1
    DT[:dispatched_at] = Time.now unless DT.key?(:dispatched_at)

    Time.now - DT[:dispatched_at] > 5
  else
    false
  end
end

assert_equal [1], DT[:deliveries]
assert_equal ["failing"], Karafka::Admin.read_topic(DT.topics[1], 0, 10).map(&:raw_payload)
