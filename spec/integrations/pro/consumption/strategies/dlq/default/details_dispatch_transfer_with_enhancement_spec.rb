# frozen_string_literal: true

# When DLQ transfer occurs, we should be able to build our own payload and headers via
# `#enhance_dlq_message`

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end

  private

  def enhance_dlq_message(dlq_message, skippable_message)
    dlq_message[:payload] = { orig: skippable_message.raw_payload, extra: 1 }.to_json
    dlq_message[:headers]['total-remap'] = 'yes'
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
  cg = Karafka::App.consumer_groups.first.id

  expected_payload = { orig: elements[i], extra: 1 }.to_json

  assert_equal dlq_message.raw_payload, expected_payload
  assert_equal dlq_message.headers["test#{i}"], (i + 1).to_s
  assert_equal dlq_message.headers.fetch('original_topic'), DT.topic
  assert_equal dlq_message.headers.fetch('original_partition'), 0.to_s
  assert_equal dlq_message.headers.fetch('original_offset'), i.to_s
  assert_equal dlq_message.headers.fetch('original_consumer_group'), cg
  assert_equal dlq_message.headers.fetch('total-remap'), 'yes'
end
