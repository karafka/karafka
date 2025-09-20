# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka in swarm should properly handle subscription group inclusion flag
# and only process the specified subscription groups

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("#{topic.subscription_group.name}:#{topic.name}")
    WRITER.flush
  end
end

# Generate unique subscription group names
SG_NAMES = DT.uuids(3).map { |uuid| "sg_#{uuid}" }

draw_routes do
  consumer_group DT.consumer_group do
    subscription_group SG_NAMES[0] do
      topic DT.topics[0] do
        consumer Consumer
      end
    end

    subscription_group SG_NAMES[1] do
      topic DT.topics[1] do
        consumer Consumer
      end
    end

    subscription_group SG_NAMES[2] do
      topic DT.topics[2] do
        consumer Consumer
      end
    end
  end
end

ARGV[0] = 'swarm'
ARGV[1] = '--subscription-groups'
ARGV[2] = "#{SG_NAMES[0]},#{SG_NAMES[2]}"

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

::Process.kill('QUIT', ::Process.pid)
thread.join

# Should only consume from SG_NAMES[0] and SG_NAMES[2], not SG_NAMES[1]
sg0 = SG_NAMES[0]
sg1 = SG_NAMES[1]
sg2 = SG_NAMES[2]
t0 = DT.topics[0]
t1 = DT.topics[1]
t2 = DT.topics[2]

assert(
  consumed.any? { |c| c.include?(sg0) },
  "Expected to consume from #{sg0} but didn't"
)

assert(
  consumed.any? { |c| c.include?(sg2) },
  "Expected to consume from #{sg2} but didn't"
)

assert(
  consumed.none? { |c| c.include?(sg1) },
  "Should NOT have consumed from excluded #{sg1}"
)

# Verify we got messages from the correct topics
assert(
  consumed.any? { |c| c.include?(t0) },
  "Expected messages from #{sg0}'s topic #{t0}"
)

assert(
  consumed.any? { |c| c.include?(t2) },
  "Expected messages from #{sg2}'s topic #{t2}"
)

assert(
  consumed.none? { |c| c.include?(t1) },
  "Should NOT have messages from excluded #{sg1}'s topic #{t1}"
)
