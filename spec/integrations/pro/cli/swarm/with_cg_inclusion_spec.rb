# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka in swarm should properly handle consumer group inclusion flag
# and only process the specified consumer groups

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("#{topic.consumer_group.name}:#{topic.name}")
    WRITER.flush
  end
end

draw_routes do
  consumer_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  consumer_group DT.consumer_groups[1] do
    topic DT.topics[1] do
      consumer Consumer
    end
  end

  consumer_group DT.consumer_groups[2] do
    topic DT.topics[2] do
      consumer Consumer
    end
  end
end

ARGV[0] = 'swarm'
ARGV[1] = '--consumer-groups'
ARGV[2] = "#{DT.consumer_groups[0]},#{DT.consumer_groups[2]}"

produce_many(DT.topics[0], DT.uuids(5))
produce_many(DT.topics[1], DT.uuids(5))
produce_many(DT.topics[2], DT.uuids(5))

thread = Thread.new { Karafka::Cli.start }

consumed = []
2.times do
  consumed << READER.gets.strip
rescue Errno::EIO
  break
end

sleep(1)

::Process.kill('QUIT', ::Process.pid)
thread.join

# Should only consume from consumer_groups[0] and consumer_groups[2], not consumer_groups[1]
cg0 = DT.consumer_groups[0]
cg1 = DT.consumer_groups[1]
cg2 = DT.consumer_groups[2]

assert(
  consumed.any? { |c| c.include?(cg0) },
  "Expected to consume from #{cg0} but didn't"
)

assert(
  consumed.any? { |c| c.include?(cg2) },
  "Expected to consume from #{cg2} but didn't"
)

assert(
  consumed.none? { |c| c.include?(cg1) },
  "Should NOT have consumed from excluded #{cg1}"
)

# Verify we consumed from the correct topics
t0 = DT.topics[0]
t1 = DT.topics[1]
t2 = DT.topics[2]

assert(
  consumed.any? { |c| c.include?(t0) },
  "Expected messages from #{t0}"
)

assert(
  consumed.any? { |c| c.include?(t2) },
  "Expected messages from #{t2}"
)

assert(
  consumed.none? { |c| c.include?(t1) },
  "Should NOT have messages from #{t1}"
)
