# frozen_string_literal: true

# When we seek back and then forward from consume while librdkafka holds prefetched messages, the
# next batch should start at the seek target. No message prefetched before the seek should be
# delivered in its place.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

MESSAGES = 200

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    DT[:firsts] << messages.first.offset

    messages.each do |message|
      DT[:offsets] << message.offset

      if message.offset == 50 && !DT.key?(:back)
        DT[:back] = true
        DT[:seeks] << 10
        seek(10)

        return
      end

      next unless message.offset == 60 && DT.key?(:back) && !DT.key?(:forward)

      DT[:forward] = true
      DT[:seeks] << 150
      seek(150)

      return
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:offsets].include?(MESSAGES - 1)
end

expected = (0..50).to_a + (10..60).to_a + (150...MESSAGES).to_a

assert_equal expected, DT[:offsets]
# Each seek target starts the batch that comes after it
DT[:seeks].each { |target| assert DT[:firsts].include?(target) }
