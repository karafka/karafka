# frozen_string_literal: true

# We should be able to create a swarm with static members that can go up and down and receive same
# assignments.
#
# They also should not conflict with each other meaning each of them should consume some data and
# there should be no fencing

setup_karafka do |config|
  config.swarm.nodes = 2
  config.kafka[:'group.instance.id'] = SecureRandom.uuid
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("#{partition}-#{Process.pid}")
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 10)
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(100))

results = {}

# No specs needed because if fenced, will fail
start_karafka_and_wait_until(mode: :swarm) do
  loop do
    partition_id, pid = READER.gets.strip.split('-')
    results[pid] ||= Set.new
    results[pid] << partition_id

    break if results.size == 2 && results.values.all? { |sub| sub.size >= 2 }

    sleep(1)
  end

  true
end
