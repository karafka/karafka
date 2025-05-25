# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments collapse should work when there is a topic that was consumed with
# parallel segments and their offset assignment is even

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

Karafka::Admin.seek_consumer_group(segment1, { DT.topic => { 0 => 1, 1 => 2 } })
Karafka::Admin.seek_consumer_group(segment2, { DT.topic => { 0 => 1, 1 => 2 } })

ARGV[0] = 'parallel_segments'
ARGV[1] = 'collapse'

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('Collapse completed')
assert results.include?('successfully')

# Verify the segment origin group now has the offsets
offsets = Karafka::Admin.read_lags_with_offsets({ DT.consumer_group => [DT.topic] })
assert_equal offsets[DT.consumer_group][DT.topic][0][:offset], 1
assert_equal offsets[DT.consumer_group][DT.topic][1][:offset], 2
