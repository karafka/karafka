# frozen_string_literal: true

# Share group (KIP-932) dead letter queue when the last record of all is broken: it behaves like
# any other broken record (retried and then moved to the DLQ) and records produced later are
# picked up as well.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      raise StandardError if message.raw_payload == DT[:broken]

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

elements = DT.uuids(100)
DT[:broken] = elements.last
produce_many(DT.topics[0], elements)

extra = SecureRandom.hex(6)

start_karafka_and_wait_until do
  # Send one more when we reached all the healthy ones
  if DT[:accepted].size >= 99 && !DT.key?(:extra)
    DT[:extra] = true
    produce(DT.topics[0], extra)
  end

  DT[:accepted].include?(extra) && !Karafka::Admin.read_topic(DT.topics[1], 0, 10).empty?
end

# First error and two errors on retries prior to moving on
assert_equal 3, DT[:errors].size
assert_equal (elements[0..98] + [extra]).sort, DT[:accepted].sort

broken = Karafka::Admin.read_topic(DT.topics[1], 0, 10)
assert_equal 1, broken.size
# This message gets a new offset (first) in the DLQ topic
assert_equal 0, broken[0].offset
assert_equal elements.last, broken[0].raw_payload
