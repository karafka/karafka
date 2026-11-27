# frozen_string_literal: true

# Seeks to `:earliest`, to a `Time` and to `:latest` from consume, while librdkafka holds
# prefetched messages, should each continue from where the seek points. The drain takes many
# prefetched messages in one go and can plan its own seeks, so none of the messages taken before a
# seek may be delivered after it.
#
# Small partition fetches and a slow first batch make librdkafka queue the messages before we poll
# again.

FIRST = 50
SECOND = 50
LATER = 10

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 20
end

module DrainTracker
  def poll_batch_nb(...)
    items = super
    DT[:drains] << items.size unless items.empty?
    items
  end
end

Rdkafka::Consumer.prepend(DrainTracker)

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each do |message|
      DT[:offsets] << message.offset

      case message.offset
      when 30
        DT[:at_30] << true

        if DT[:at_30].size == 1
          seek(:earliest)
        else
          seek(DT[:time].first)
        end

        return
      when 70
        next if DT.key?(:latest)

        DT[:latest] = true
        seek(:latest)

        return
      end
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(FIRST))
sleep(1.1)
DT[:time] << Time.now
produce_many(DT.topic, DT.uuids(SECOND))

Thread.new do
  sleep(0.1) until DT.key?(:latest)
  sleep(2)
  produce_many(DT.topic, DT.uuids(LATER))
end

start_karafka_and_wait_until do
  DT[:offsets].last == FIRST + SECOND + LATER - 1
end

assert !DT[:drains].empty?

expected = (0..30).to_a * 2 + (FIRST..70).to_a + (FIRST + SECOND...FIRST + SECOND + LATER).to_a

assert_equal expected, DT[:offsets]
