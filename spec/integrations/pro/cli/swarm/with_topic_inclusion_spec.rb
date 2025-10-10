# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka in swarm should properly handle topic inclusion flag
# and only process the specified topics

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts(topic.name)
    WRITER.flush
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topics[0] do
      consumer Consumer
    end

    topic DT.topics[1] do
      consumer Consumer
    end

    topic DT.topics[2] do
      consumer Consumer
    end
  end
end

ARGV[0] = 'swarm'
ARGV[1] = '--topics'
ARGV[2] = "#{DT.topics[0]},#{DT.topics[2]}"

produce_many(DT.topics[0], DT.uuids(5))
produce_many(DT.topics[1], DT.uuids(5))
produce_many(DT.topics[2], DT.uuids(5))

thread = Thread.new { Karafka::Cli.start }

consumed = Set.new
while consumed.size < 2
  begin
    consumed << READER.gets.strip
  rescue Errno::EIO
    break
  end
end

Process.kill('QUIT', Process.pid)
thread.join

# Should only consume from topics[0] and topics[2], not topics[1]
t0 = DT.topics[0]
t1 = DT.topics[1]
t2 = DT.topics[2]

assert(
  consumed.any?(t0),
  "Expected to consume from #{t0} but didn't"
)

assert(
  consumed.any?(t2),
  "Expected to consume from #{t2} but didn't"
)

assert(
  consumed.none?(t1),
  "Should NOT have consumed from excluded topic #{t1}"
)
