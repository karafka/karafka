# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments collapse should fail when parallel segments have inconclusive offsets

setup_karafka

segment1 = "#{DT.consumer_group}-parallel-0"
segment2 = "#{DT.consumer_group}-parallel-1"

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

produce_many(DT.topic, DT.uuids(10))

Karafka::Admin.seek_consumer_group(segment1, { DT.topic => { 0 => 5, 1 => 2 } })
Karafka::Admin.seek_consumer_group(segment2, { DT.topic => { 0 => 3, 1 => 8 } })

ARGV[0] = 'parallel_segments'
ARGV[1] = 'collapse'

# The command should fail due to inconclusive offsets

failed = false
begin
  Karafka::Cli.start
rescue Karafka::Errors::CommandValidationError
  failed = true
end

assert failed
