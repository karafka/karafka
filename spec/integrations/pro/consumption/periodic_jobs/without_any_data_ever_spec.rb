# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When periodic gets an assignment it should tick in intervals despite never having any data
# It should never indicate that it was used when it was not

setup_karafka do |config|
  config.max_wait_time = 200
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    raise unless messages.empty?

    DT[:used] << used?
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic interval: 100
  end
end

start_karafka_and_wait_until do
  DT[:used].count >= 5
end

assert_equal DT[:used].uniq, [false]
