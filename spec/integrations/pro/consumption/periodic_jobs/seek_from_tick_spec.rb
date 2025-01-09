# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to seek from tick

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume] << true
  end

  def tick
    seek(0)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

produce_many(DT.topic, DT.uuids(1))

# If seeking from ticking would not work, this would hang
start_karafka_and_wait_until do
  DT[:consume].count >= 5
end
