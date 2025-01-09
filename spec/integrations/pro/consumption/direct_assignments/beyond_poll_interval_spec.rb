# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When using direct assignments, we should be able to ignore max poll interval.

setup_karafka do |config|
  config.max_messages = 25
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

DT[:partitions] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    seen = DT[:partitions].include?(partition)

    return if DT[:goes].size >= 4 && seen

    sleep(15) unless seen

    DT[:goes] << true
    DT[:partitions] << partition
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 2)
    assign(0, 1)
  end
end

2.times do |i|
  elements = DT.uuids(200)
  produce_many(DT.topic, elements, partition: i)
end

start_karafka_and_wait_until do
  DT[:partitions].size >= 2 && DT[:goes].size >= 4
end
