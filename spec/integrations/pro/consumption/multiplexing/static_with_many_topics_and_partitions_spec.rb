# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to have static group membership with cooperative on many topics and partitions
# with multiplexing starting with 1 without any issues.

setup_karafka do |config|
  config.concurrency = 10
  config.kafka[:'group.instance.id'] = SecureRandom.uuid
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

DT[:used] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:used] << "#{topic.name}-#{partition}"
  end
end

draw_routes do
  subscription_group do
    multiplexing(max: 2, boot: 1, min: 1)

    10.times do |i|
      topic DT.topics[i] do
        config(partitions: 10)
        consumer Consumer
        non_blocking_job true
        manual_offset_management true
      end
    end
  end
end

10.times do |i|
  10.times do |j|
    produce_many(DT.topics[i], DT.uuids(1), partition: j)
  end
end

start_karafka_and_wait_until do
  DT[:used].size >= 100
end
