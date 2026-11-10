# frozen_string_literal: true

# Karafka::Admin.copy_dead_letter_queue should copy messages the OSS DLQ dispatched to the given
# target topic, adding the replay count header. The OSS DLQ keeps only the payload, so the
# copied message has no key and no original headers.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.offset == 5

      mark_as_consumed message
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    DT[:broken] << messages.first.offset
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

Karafka::Admin.create_topic(DT.topics[2], 1, 1)

elements = DT.uuids(10)
produce_many(DT.topics[0], elements, key: "key", headers: { "user" => "value" })

start_karafka_and_wait_until do
  DT.key?(:broken)
end

# Karafka closes its producer when it stops
producer = WaterDrop::Producer.new do |config|
  config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

copied = Karafka::Admin.copy_dead_letter_queue(
  DT.topics[1],
  target_topic_name: DT.topics[2],
  producer: producer
)

assert_equal 1, copied

replayed = Karafka::Admin.read_topic(DT.topics[2], 0, 10, 0)

assert_equal 1, replayed.size
assert_equal elements[5], replayed.first.raw_payload
assert_equal nil, replayed.first.raw_key
assert_equal({ "replay_count" => "1" }, replayed.first.raw_headers)

producer.close
