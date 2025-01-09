# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to mark as consumed from ticking if we want to

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def tick
    return if messages.empty?

    DT[:marked] << messages.first.offset
    mark_as_consumed messages.first
    DT[:ticks] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:ticks].count >= 2
end

assert_equal fetch_next_offset - 1, DT[:marked].last
