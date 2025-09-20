# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka in swarm should properly handle topic exclusion flag
# and skip processing the specified topics

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
ARGV[1] = '--exclude-topics'
ARGV[2] = DT.topics[1]

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

# Give it more time to process messages
sleep(1)

::Process.kill('QUIT', ::Process.pid)
thread.join

# Should consume from topics[0] and topics[2], but not topics[1] (which was excluded)
t0 = DT.topics[0]
t1 = DT.topics[1]
t2 = DT.topics[2]

assert(
  consumed.any? { |c| c == t0 },
  "Expected to consume from #{t0} but didn't"
)

assert(
  consumed.any? { |c| c == t2 },
  "Expected to consume from #{t2} but didn't"
)

assert(
  consumed.none? { |c| c == t1 },
  "Should NOT have consumed from excluded topic #{t1}"
)
