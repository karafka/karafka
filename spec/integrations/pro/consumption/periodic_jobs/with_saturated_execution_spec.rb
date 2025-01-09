# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(10)
    DT[:c] << Time.now.to_f
  end

  def tick
    DT[:t] << Time.now.to_f
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

produce_many(DT.topic, DT.uuids(1), partition: 0)

start_karafka_and_wait_until do
  DT.key?(:c) && DT.key?(:t)
end

assert DT[:t].first - DT[:c].first >= 5
