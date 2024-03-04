# frozen_string_literal: true

# We should be able to use direct assignments per node with ranges

setup_karafka do |config|
  config.swarm.nodes = 2
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("#{partition}-#{Process.pid}")
    WRITER.flush
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 5)
    assign(true)
    swarm(nodes: { 0 => 0..2, 1 => 3..4 })
    consumer Consumer
  end
end

5.times do |partition|
  produce_many(DT.topic, DT.uuids(10), partition: partition)
end

done = Set.new
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets.strip
  done.size >= 5
end

results = {}

done.each do |result|
  partition, pid = result.split('-')

  results[pid] ||= []
  results[pid] << partition
end

results.transform_values! { |partitions| partitions.map(&:to_i).sort }

groups = [[0, 1, 2], [3, 4]]

assert groups.include?(results.values.first)
assert groups.include?(results.values.last)
assert_equal 2, groups.size
