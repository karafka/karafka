# frozen_string_literal: true

# Karafka commits the stored offsets, so the `client.offsets.committed` list has every assigned
# partition. A partition with nothing to commit is in it with a nil offset.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed!(messages.last)
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
  end
end

committed = Queue.new

Karafka::App.monitor.subscribe("client.offsets.committed") do |event|
  committed << event[:tpl].to_h.fetch(DT.topic, [])
end

produce(DT.topic, "1", partition: 0)

offsets = nil

start_karafka_and_wait_until do
  offsets = committed.pop until committed.empty?

  offsets&.any? { |partition| partition.partition.zero? && partition.offset == 1 }
end

assert_equal(
  [[0, 1], [1, nil]],
  offsets.map { |partition| [partition.partition, partition.offset] }.sort_by(&:first)
)
