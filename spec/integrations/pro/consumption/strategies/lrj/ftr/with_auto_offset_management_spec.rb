# frozen_string_literal: true

# When using automatic offset management, we should end up with offset committed after the last
# message and we should "be" there upon returning to processing. Throttling should have nothing
# to do with this.

setup_karafka do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.last.offset
    # We sleep here so we don't end up consuming so many messages, that the second consumer would
    # hang as there would be no data for him
    sleep(1)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    throttling(limit: 1, interval: 2_000)
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[0].size > 1
end

assert_equal DT[0].last + 1, fetch_next_offset
