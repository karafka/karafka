# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to use direct assignments per node

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
    # Setup this topic with 2 partitions
    config(partitions: 2)
    # Use direct assignment mode and operate on two partitions
    assign(0, 1)
    # Assign proper partitions to proper nodes
    swarm(nodes: { 0 => [0], 1 => [1] })
    consumer Consumer
  end
end

2.times do |partition|
  produce_many(DT.topic, DT.uuids(10), partition: partition)
end

done = Set.new
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets.strip
  done.size >= 2
end

# Two processes should get assignments
assert_equal 2, done.map { |report| report.split('-').last }.uniq.size
