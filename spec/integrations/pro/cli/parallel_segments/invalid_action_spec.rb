# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments should fail with ArgumentError when an invalid action is provided

setup_karafka

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 2,
      partitioner: ->(msg) { msg.key }
    )
    topic DT.topic do
      config(partitions: 2)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

ARGV[0] = 'parallel_segments'
ARGV[1] = 'invalid_action'

failed = false
begin
  Karafka::Cli.start
rescue ArgumentError
  failed = true
end

assert failed
