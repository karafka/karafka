# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments reset should perform both collapse and distribute operations

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

# Set different offsets for segments to test collapse
Karafka::Admin.seek_consumer_group(segment1, { DT.topic => { 0 => 5, 1 => 2 } })
Karafka::Admin.seek_consumer_group(segment2, { DT.topic => { 0 => 5, 1 => 2 } })

# Set offsets for the origin consumer group (needed for distribute part of reset)
Karafka::Admin.seek_consumer_group(DT.consumer_group, { DT.topic => { 0 => 5, 1 => 2 } })

ARGV[0] = 'parallel_segments'
ARGV[1] = 'reset'
ARGV[2] = '--force' # Use force to bypass validation

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('Collapse completed')
assert results.include?('Distribution completed')
assert results.include?('successfully')

# Verify the origin consumer group received the offsets
origin_offsets = Karafka::Admin.read_lags_with_offsets({ DT.consumer_group => [DT.topic] })
assert_equal origin_offsets[DT.consumer_group][DT.topic][0][:offset], 5
assert_equal origin_offsets[DT.consumer_group][DT.topic][1][:offset], 2

# Verify segments received the offsets back from origin
segment1_offsets = Karafka::Admin.read_lags_with_offsets({ segment1 => [DT.topic] })
segment2_offsets = Karafka::Admin.read_lags_with_offsets({ segment2 => [DT.topic] })
assert_equal segment1_offsets[segment1][DT.topic][0][:offset], 5
assert_equal segment1_offsets[segment1][DT.topic][1][:offset], 2
assert_equal segment2_offsets[segment2][DT.topic][0][:offset], 5
assert_equal segment2_offsets[segment2][DT.topic][1][:offset], 2
