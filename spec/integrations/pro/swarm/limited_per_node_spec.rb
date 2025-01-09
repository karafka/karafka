# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to instruct swarm to run consumption only on a certain node despite having more

setup_karafka do |config|
  config.swarm.nodes = 3
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
    swarm(nodes: [0])
    consumer Consumer
  end

  topic DT.topics[1] do
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

# Only one process should get assignments since we've limited that
assert_equal 1, done.map { |report| report.split('-').last }.uniq.size
