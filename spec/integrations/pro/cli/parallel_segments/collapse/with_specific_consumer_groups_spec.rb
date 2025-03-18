# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments collapse should work with specific consumer groups selected

setup_karafka

segment_1_1 = "#{DT.consumer_group}-parallel-0"
segment_1_2 = "#{DT.consumer_group}-parallel-1"

segment_2_1 = "#{DT.consumer_group}_2-parallel-0"
segment_2_2 = "#{DT.consumer_group}_2-parallel-1"

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

  consumer_group "#{DT.consumer_group}_2" do
    parallel_segments(
      count: 2,
      partitioner: ->(msg) { msg.key }
    )
    topic "#{DT.topic}_2" do
      config(partitions: 2)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

produce_many(DT.topic, DT.uuids(10))
produce_many("#{DT.topic}_2", DT.uuids(10))

Karafka::Admin.seek_consumer_group(segment_1_1, { DT.topic => { 0 => 3, 1 => 5 } })
Karafka::Admin.seek_consumer_group(segment_1_2, { DT.topic => { 0 => 3, 1 => 5 } })

Karafka::Admin.seek_consumer_group(segment_2_1, { "#{DT.topic}_2" => { 0 => 6, 1 => 8 } })
Karafka::Admin.seek_consumer_group(segment_2_2, { "#{DT.topic}_2" => { 0 => 6, 1 => 8 } })

# Run collapse only for the first consumer group
ARGV[0] = 'parallel_segments'
ARGV[1] = 'collapse'
ARGV[2] = '--groups'
ARGV[3] = DT.consumer_group

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('Collapse completed')
assert results.include?('successfully')
assert results.include?(DT.consumer_group)
assert !results.include?("#{DT.consumer_group}_2")

# Verify only the first consumer group was collapsed
offsets1 = Karafka::Admin.read_lags_with_offsets({ DT.consumer_group => [DT.topic] })
assert_equal offsets1[DT.consumer_group][DT.topic][0][:offset], 3
assert_equal offsets1[DT.consumer_group][DT.topic][1][:offset], 5

# The second group should have no offsets in the origin consumer group
offsets2 = Karafka::Admin.read_lags_with_offsets({ "#{DT.consumer_group}_2" => ["#{DT.topic}_2"] })
assert_equal offsets2["#{DT.consumer_group}_2"]["#{DT.topic}_2"][0][:offset], -1
assert_equal offsets2["#{DT.consumer_group}_2"]["#{DT.topic}_2"][1][:offset], -1
