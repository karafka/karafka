# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments collapse should work when there are multiple (10) segments

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

segments.each do |segment|
  Karafka::Admin.seek_consumer_group(
    segment,
    {
      DT.topic => {
        0 => 5,
        1 => 7,
        2 => 3,
        3 => 9
      }
    }
  )
end

ARGV[0] = 'parallel_segments'
ARGV[1] = 'collapse'

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('Collapse completed')
assert results.include?('successfully')

offsets = Karafka::Admin.read_lags_with_offsets({ DT.consumer_group => [DT.topic] })
assert_equal offsets[DT.consumer_group][DT.topic][0][:offset], 5
assert_equal offsets[DT.consumer_group][DT.topic][1][:offset], 7
assert_equal offsets[DT.consumer_group][DT.topic][2][:offset], 3
assert_equal offsets[DT.consumer_group][DT.topic][3][:offset], 9
