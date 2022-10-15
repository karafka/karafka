# frozen_string_literal: true

# When we consume data and several times we loose and regain partition, there should be
# continuity in what messages we pick up even if rebalances happens multiple times
#
# We may re-fetch certain messages but none should be skipped

setup_karafka do |config|
  config.concurrency = 1
  config.manual_offset_management = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:messages] << message.offset

      return unless mark_as_consumed!(message)
    end
  end
end

draw_routes Consumer

MESSAGES = DT.uuids(1_000)

# We need a second producer to trigger the rebalances
Thread.new do
  sleep(10)

  10.times do
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topic)
    sleep(2)
    consumer.close
    sleep(1)
  end

  DT[:rebalanced] << true
end

i = 0

start_karafka_and_wait_until do
  10.times do
    produce(DT.topic, MESSAGES[i])
    i += 1
  end

  sleep(1)

  DT[:rebalanced].size >= 1
end

previous = nil

# They need to be in order one batch after another
DT[:messages].uniq.each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
