# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we are just getting new data, we should delay to match time expectations

setup_karafka { |config| config.max_messages = 10 }

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
    # 5 seconds
    delay_by(5_000)
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(rand(20)))

  sleep(0.1)

  DT[0].count >= 100
end

# All should be delivered and all should be old enough
previous = -1

DT[0].each do |offset, timestamp|
  assert_equal previous + 1, offset
  previous = offset

  assert Time.now.utc - timestamp > 5
end
