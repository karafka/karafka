# frozen_string_literal: true

# When iterating over the topic from the same time on all partitions, we should start from the
# expected on all and finish accordingly

setup_karafka

draw_routes do
  topic DT.topic do
    config(partitions: 5)
    active false
  end
end

start_time = nil

10.times do |index|
  start_time = Time.now if index == 5

  5.times do |partition_nr|
    produce(DT.topic, DT.uuid, partition: partition_nr)
  end

  sleep(0.5)
end

partitioned_data = Hash.new { |h, v| h[v] = [] }

iterator = Karafka::Pro::Iterator.new({ DT.topic => start_time })

iterator.each do |message|
  partitioned_data[message.partition] << message.offset
end

partitioned_data.each do |_, data|
  assert_equal (5..9).to_a, data
end
