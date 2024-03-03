# frozen_string_literal: true

# We should be able to assign to ourselves direct ownership of partitions we are interested in

setup_karafka

DT[:partitions] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:partitions] << partition
  end

  def shutdown
    DT[:shutdowns] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 2)
    assign(0, 1)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:partitions].size >= 2
end

assert_equal 2, DT[:shutdowns].count
