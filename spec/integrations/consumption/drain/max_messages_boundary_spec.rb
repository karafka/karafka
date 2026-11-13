# frozen_string_literal: true

# When more messages are already fetched than fit in one batch, Karafka should take only as many as
# `max_messages` allows. The rest should come in the next batches, in order and without gaps.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

MAX_MESSAGES = 10
MESSAGES = 100

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = MAX_MESSAGES
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    DT[:sizes] << messages.size
    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:offsets].size >= MESSAGES
end

assert_equal (0...MESSAGES).to_a, DT[:offsets]
assert DT[:sizes].all? { |size| size <= MAX_MESSAGES }
# After the slow first batch all the messages are prefetched, so every batch is full
assert DT[:sizes][1..].count(MAX_MESSAGES) >= (MESSAGES / MAX_MESSAGES) - 2
