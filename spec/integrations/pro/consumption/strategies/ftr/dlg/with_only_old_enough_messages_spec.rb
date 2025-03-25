# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When Karafka delays processing and we have only old messages, there should be no pausing or
# seeking and we should just process

setup_karafka { |config| config.max_messages = 10 }

class Listener
  def on_filtering_seek(_)
    DT[:unexpected] << true
  end

  def on_filtering_throttled(_)
    DT[:unexpected] << true
  end
end

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [
        message.offset,
        message.timestamp
      ]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # 2 seconds
    delay_by(2_000)
  end
end

produce_many(DT.topic, DT.uuids(50))

sleep(2)

start_karafka_and_wait_until do
  DT[0].size >= 50
end

assert DT[:unexpected].empty?

# All should be delivered and all should be old enough
previous = -1

DT[0].each do |offset, timestamp|
  assert_equal previous + 1, offset
  previous = offset

  assert Time.now.utc - timestamp > 2
end
