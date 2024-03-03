# frozen_string_literal: true

# We should be able to assign to ourselves direct ownership of all partitions

setup_karafka

DT[:partitions] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:partitions] << partition
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 5)
    assign(true)
  end
end

5.times do |i|
  produce_many(DT.topic, DT.uuids(2), partition: i)
end

start_karafka_and_wait_until do
  DT[:partitions].size >= 5
end
