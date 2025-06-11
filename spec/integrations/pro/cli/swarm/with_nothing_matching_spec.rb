# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka in swarm should raise well nested validated errors with the swarm context

setup_karafka

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      config(partitions: 2)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

ARGV[0] = 'swarm'
ARGV[1] = '--topics'
ARGV[2] = 't1,t2'

failed = false

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?('swarm.cli.include_topics')
  failed = true
end

assert failed
