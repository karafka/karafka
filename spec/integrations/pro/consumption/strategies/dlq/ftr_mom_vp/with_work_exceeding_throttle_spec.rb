# frozen_string_literal: true

# When doing work that is exceeding timeouts, we should not throttle. Instead we need to seek
# to the first throttled message and just move on. DLQ should not interact with this in any way.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end

    sleep(2)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    manual_offset_management(true)
    throttling(
      limit: 2,
      interval: 1_000
    )
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end
end

# This should never happen because throttle expires and we seek to the correct location
Karafka.monitor.subscribe 'filtering.throttled' do
  raise
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  # This needs to run for a while as on slow CIs things pick up slowly
  sleep(15)
end

# All messages should be received and seek should work correctly
# Order may be not as expected due to random VPs
assert_equal DT[0].sort, (0...DT[0].size).to_a.sort
assert fetch_first_offset.zero?
