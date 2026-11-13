# frozen_string_literal: true

# When a message is skipped to the DLQ while the messages after it are already fetched, the
# skipped message should not be delivered again and the next one should. The DLQ topic should
# get only the skipped message.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

MESSAGES = 100
FAILING = 30

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each do |message|
      raise StandardError if message.offset == FAILING

      DT[:offsets] << message.offset

      mark_as_consumed message
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:broken] << message.raw_payload }
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

elements = DT.uuids(MESSAGES)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[:offsets].size >= MESSAGES - 1 && DT.key?(:broken)
end

assert_equal (0...MESSAGES).to_a - [FAILING], DT[:offsets]
assert_equal [elements[FAILING]], DT[:broken]
