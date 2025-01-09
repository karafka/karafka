# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When the idle job kicks in before we had a chance to process any data, it should still have
# access to empty messages batch with proper offset positions (-1001) and no messages.
#
# It should also kick in proper instrumentation event that we can use prior to scheduling

setup_karafka

Karafka.monitor.subscribe('filtering.throttled') do
  DT[:done] << true
end

Karafka.monitor.subscribe('consumer.before_schedule_idle') do
  DT[:before_schedule_idle] << true
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
assert_equal messages.metadata.processed_at, nil
assert !messages.metadata.created_at.nil?
assert messages.empty?
assert DT.key?(:before_schedule_idle)
