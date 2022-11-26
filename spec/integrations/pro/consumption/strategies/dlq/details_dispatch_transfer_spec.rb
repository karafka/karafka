# frozen_string_literal: true

# When DLQ transfer occurs, payload and many other things should be transferred to the DLQ topic.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(2)

2.times do |i|
  produce(DT.topic, elements[i], headers: { "test#{i}" => (i + 1).to_s })
end

start_karafka_and_wait_until do
  DT[:broken].size >= 2
end

2.times do |i|
  dlq_message = DT[:broken][i]

  assert_equal dlq_message.raw_payload, elements[i]
  assert_equal dlq_message.headers["test#{i}"], (i + 1).to_s
  assert_equal dlq_message.headers['original_topic'], DT.topic
  assert_equal dlq_message.headers['original_partition'], 0.to_s
  assert_equal dlq_message.headers['original_offset'], i.to_s
end
