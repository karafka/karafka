# frozen_string_literal: true

# We should be able to use DLQ in a pipeline where we handle each stage separately.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class LastConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << [message.offset, message.raw_payload]
    end
  end
end

draw_routes do
  4.times do |i|
    topic DT.topics[i] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[i + 1], max_retries: 1)
    end
  end

  topic DT.topics[4] do
    consumer LastConsumer
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

elements = DT.uuids(1)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:broken].size >= 1
end

assert_equal 1, DT[:broken].size
# This message will get new offset (first)
assert_equal DT[:broken][0][0], 0
assert_equal DT[:broken][0][1], elements[0]
