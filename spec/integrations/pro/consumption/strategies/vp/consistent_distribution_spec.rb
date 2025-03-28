# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should always assign same consumer instance to the same virtual partitioner result.
# In case data from few virtual partitions is merged into one chunk, the partition should always
# stay the same (consistent).

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 100
  config.initial_offset = 'earliest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    group = Set.new
    messages.each { |message| group << message.raw_payload }

    DT[:combinations] << [group.to_a, object_id]
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

Thread.new do
  loop do
    produce_many(DT.topic, (0..10).to_a.map(&:to_s).shuffle)
    sleep(0.1)
  rescue WaterDrop::Errors::ProducerClosedError
    break
  end
end

start_karafka_and_wait_until do
  DT[:combinations].size >= 20
end

assignments = {}

DT[:combinations].each do |elements|
  group, consumer = elements

  group.each do |element|
    assignments[element] ||= Set.new
    assignments[element] << consumer
  end
end

assert(assignments.values.map(&:size).all? { _1 == 1 })
