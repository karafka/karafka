# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we collapse VPs manually, the `#collapse?` should NOT change for the currently running
# operation and only should collapse later

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 50
end

MUTEX = Mutex.new
DT[:in_progress] = 0

class Consumer < Karafka::BaseConsumer
  def consume
    MUTEX.synchronize { DT[:in_progress] += 1 }

    messages.each do
      DT[0] << true
    end

    if DT[:in_progress] > 1 && !DT.key?(:collapsed)
      # Something far in the future, so we're collapsed from start
      collapse_until!(10_000)

      DT[:collisions] << [collapsed?, Thread.current.object_id]

      sleep(5)

      DT[:collapsed] = true
    end

    sleep(5) unless DT.key?(:collapsed)

    MUTEX.synchronize { DT[:in_progress] -= 1 }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(1000))

start_karafka_and_wait_until do
  DT[0].size >= 1000
end

threads = []

# None of those should report as true because the collapse should only impact future batches and
# not the one currently being processed in VPs
DT[:collisions].each do |sample|
  threads << sample.last
  assert_equal false, sample.first
end

# Should not run in same thread when not collapsed
assert_equal threads.uniq, threads
