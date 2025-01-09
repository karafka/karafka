# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When Karafka encounters messages that are too old, it should skip them
# We simulate this by having short ttl and delaying processing to build up a lag

setup_karafka { |config| config.max_messages = 5 }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [
        message.offset,
        Time.now.utc - message.timestamp
      ]
    end

    sleep(0.2)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # 1 second
    expire_in(1_000)
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(5))

  DT[0].count >= 50
end

# None of them should be older than 1 second
# Messages here can be slightly older than 1 second because there may be a distance in between the
# moment we filtered and the moment we're processing. That is why we're adding 500 ms
# We add 500ms because 200ms was not enough for slow CI with hiccups
assert(DT[0].map(&:last).all? { |age| age < 1.5 })

previous = nil
gap = false

# There should be skips in messages
DT[0].map(&:first).each do |offset|
  unless previous
    previous = offset
    next
  end

  gap = true if offset - previous > 1

  previous = offset
end

assert gap
