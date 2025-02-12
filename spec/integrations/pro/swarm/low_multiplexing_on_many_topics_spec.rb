# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Swarm should work with a single subscription group with many topics and many partitions.

setup_karafka do |config|
  config.swarm.nodes = 5
  config.kafka[:'group.id'] = SecureRandom.uuid
  config.kafka[:'group.instance.id'] = SecureRandom.uuid
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("#{topic.name}-#{partition}")
  end
end

draw_routes do
  subscription_group do
    multiplexing(max: 2, min: 1, boot: 1)

    10.times do |i|
      topic DT.topics[i] do
        consumer Consumer
        config(partitions: 10)
        non_blocking_job true
        manual_offset_management true

        next if i < 5

        delay_by(5_000)
      end
    end
  end
end

10.times do |i|
  10.times do |j|
    produce_many(DT.topics[i], DT.uuids(1), partition: j)
  end
end

DT[:used] = Set.new

start_karafka_and_wait_until(mode: :swarm) do
  DT[:used] << READER.gets
  DT[:used].size >= 100
end
