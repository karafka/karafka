# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When iterating over different topics/partitions with different times, each should start from
# the expected one.

setup_karafka

draw_routes do
  topic DT.topic do
    config(partitions: 5)
    active false
  end
end

start_times = {}

10.times do |index|
  start_times[index] = Time.now

  5.times do |partition_nr|
    produce(DT.topic, DT.uuid, partition: partition_nr)
  end

  sleep(0.5)
end

partitioned_data = Hash.new { |h, v| h[v] = [] }

partitions = start_times.map { |partition, time| [partition, time] }.first(5).to_h

iterator = Karafka::Pro::Iterator.new({ DT.topic => partitions })

iterator.each do |message|
  partitioned_data[message.partition] << message.offset
end

partitioned_data.each do |partition, data|
  assert_equal (partition..9).to_a, data
end
