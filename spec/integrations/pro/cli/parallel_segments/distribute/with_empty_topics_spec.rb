# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments distribute should work with empty topics

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

# Create topic but don't produce any messages, so it's empty

ARGV[0] = 'parallel_segments'
ARGV[1] = 'distribute'

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('Distribution completed')
assert results.include?('successfully')

# Verify offsets were distributed to both segments
offsets1 = Karafka::Admin.read_lags_with_offsets({ segment1 => [DT.topic] })
offsets2 = Karafka::Admin.read_lags_with_offsets({ segment2 => [DT.topic] })

assert_equal offsets1[segment1][DT.topic][0][:offset], -1
assert_equal offsets1[segment1][DT.topic][1][:offset], -1
assert_equal offsets2[segment2][DT.topic][0][:offset], -1
assert_equal offsets2[segment2][DT.topic][1][:offset], -1
