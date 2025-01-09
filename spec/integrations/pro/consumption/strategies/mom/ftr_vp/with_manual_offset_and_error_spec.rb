# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using manual offset management with throttling, an error should move us back to where we
# had the last offset, but throttle backoff should continue linear.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 2
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    @runs ||= 0

    messages.each do |message|
      DT[:offsets] << message.offset
    end

    coordinator.synchronize do
      @runs += 1

      return unless @runs == 4 && DT[:executed].empty?

      sleep(1)

      DT[:executed] << true
      # The -1 will act as a divider so it's easier to spec things
      DT[:split] << DT[:offsets].size
      raise StandardError
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    throttling(limit: 2, interval: 100)
    virtual_partitions(
      partitioner: ->(_msg) { rand(2) }
    )
  end
end

Thread.new do
  loop do
    produce(DT.topic, '1', partition: 0)

    sleep(0.1)
  rescue StandardError
    nil
  end
end

start_karafka_and_wait_until do
  DT[:offsets].size >= 20
end

split = DT[:split].first

before = DT[:offsets][0..(split - 1)]
after = DT[:offsets][split..100]

# It is expected to reprocess all since consumer was created even when there are more batches
# We need to check both because we may not reached the split moment one way or the other
assert((before - after).empty? || (after - before).empty?)
