# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments distribute should work with multiple segments

setup_karafka

segments = Array.new(10) { |i| "#{DT.consumer_group}-parallel-#{i}" }

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 10,
      partitioner: ->(msg) { msg.key }
    )

    topic DT.topic do
      config(partitions: 4)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

produce_many(DT.topic, DT.uuids(20))

# Set offsets in the origin consumer group
Karafka::Admin.seek_consumer_group(
  DT.consumer_group,
  {
    DT.topic => {
      0 => 5,
      1 => 7,
      2 => 3,
      3 => 9
    }
  }
)

ARGV[0] = 'parallel_segments'
ARGV[1] = 'distribute'

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('Distribution completed')
assert results.include?('successfully')

# Verify all segments received the offsets
segments.each do |segment|
  offsets = Karafka::Admin.read_lags_with_offsets({ segment => [DT.topic] })
  assert_equal offsets[segment][DT.topic][0][:offset], 5
  assert_equal offsets[segment][DT.topic][1][:offset], 7
  assert_equal offsets[segment][DT.topic][2][:offset], 3
  assert_equal offsets[segment][DT.topic][3][:offset], 9
end
