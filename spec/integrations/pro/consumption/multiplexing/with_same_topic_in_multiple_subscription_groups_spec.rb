# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using separate subscription groups, each should have it's own underlying client and should
# operate independently for data fetching and consumption

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:clients] << client.object_id
    DT[:consumers] << object_id
  end
end

draw_routes do
  subscription_group :sg do
    multiplexing(max: 5)

    topic DT.topic do
      config(partitions: 10)
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  10.times do |i|
    produce_many(DT.topic, DT.uuids(10), partition: i)
  end

  sleep(1)

  DT[:clients].uniq.count >= 5 && DT[:consumers].uniq.count >= 5
end

assert_equal 5, DT[:clients].uniq.size
assert DT[:consumers].uniq.size >= 5
