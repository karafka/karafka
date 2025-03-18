# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments distribute should work with --force even when offsets are already set

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

# Set initial offsets in origin consumer group
Karafka::Admin.seek_consumer_group(DT.consumer_group, { DT.topic => { 0 => 5, 1 => 7 } })

# Set existing offsets in parallel segments (that would normally cause failure)
Karafka::Admin.seek_consumer_group(segment1, { DT.topic => { 0 => 2, 1 => 3 } })

ARGV[0] = 'parallel_segments'
ARGV[1] = 'distribute'
ARGV[2] = '--force'

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('Distribution completed')
assert results.include?('successfully')

# Verify offsets were overwritten in both segments
offsets1 = Karafka::Admin.read_lags_with_offsets({ segment1 => [DT.topic] })
offsets2 = Karafka::Admin.read_lags_with_offsets({ segment2 => [DT.topic] })

# Both segments should get the offsets from origin group
assert_equal offsets1[segment1][DT.topic][0][:offset], 5
assert_equal offsets1[segment1][DT.topic][1][:offset], 7
assert_equal offsets2[segment2][DT.topic][0][:offset], 5
assert_equal offsets2[segment2][DT.topic][1][:offset], 7
