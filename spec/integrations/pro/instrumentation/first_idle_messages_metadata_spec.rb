# frozen_string_literal: true

# When the idle job kicks in before we had a chance to process any data, it should still have
# access to empty messages batch with proper offset positions (-1001) and no messages.

setup_karafka

Karafka.monitor.subscribe('filtering.throttled') do
  DT[:done] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << true
  end

  def shutdown
    DT[:messages] << messages
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    delay_by(60_000)
  end
end

produce_many(DT.topic, DT.uuids(15))

start_karafka_and_wait_until do
  !DT[:done].empty?
end

assert DT[:consumed].empty?
assert_equal DT[:messages].size, 1

messages = DT[:messages].first

assert_equal messages.metadata.first_offset, -1001
assert_equal messages.metadata.last_offset, -1001
assert_equal messages.metadata.partition, 0
assert_equal messages.metadata.size, 0
assert_equal messages.metadata.created_at, nil
assert_equal messages.metadata.processed_at, nil
