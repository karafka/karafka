# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka in swarm should raise well nested validated errors with the swarm context
# This spec will cause it to crash if any validation that would fail is happening in the nodes
# post-fork

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts(topic.name)
    WRITER.flush
  end
end

draw_routes do
  subscription_group DT.consumer_groups[0] do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  subscription_group DT.consumer_groups[1] do
    topic DT.topics[1] do
      consumer Consumer
    end
  end
end

ARGV[0] = 'swarm'
ARGV[1] = '--exclude-subscription-groups'
ARGV[2] = DT.consumer_groups[0]

produce_many(DT.topics[0], DT.uuids(10))
produce_many(DT.topics[1], DT.uuids(10))

thread = Thread.new { Karafka::Cli.start }

READER.gets

::Process.kill('QUIT', ::Process.pid)

thread.join
