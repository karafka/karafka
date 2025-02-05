# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When consuming data with virtual partitions from many batches, the order of messages in between
# the single partition batches should be preserved.

setup_karafka do |config|
  config.concurrency = 10
end

Karafka.monitor.subscribe('connection.listener.fetch_loop.received') do |event|
  next if event.payload[:messages_buffer].empty?

  DT[:batches] << []
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:batches].last << [message.offset]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

start_karafka_and_wait_until do
  if DT[:batches].map(&:size).sum < 1000
    produce_many(DT.topic, DT.uuids(100))
    sleep(1)
    false
  else
    true
  end
end

# Sort messages from each of the batches
DT[:batches].map! do |batch|
  batch.sort_by!(&:first)
end

previous = nil

# They need to be in order one batch after another
DT[:batches].flatten.each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
