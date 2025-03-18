# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments distribute should work with multiple topics

setup_karafka

segment1 = "#{DT.consumer_group}-parallel-0"
segment2 = "#{DT.consumer_group}-parallel-1"
topics = [DT.topic, "#{DT.topic}_2", "#{DT.topic}_3"]

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 2,
      partitioner: ->(msg) { msg.key }
    )

    topics.each do |topic_name|
      topic topic_name do
        config(partitions: 2)
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end
end

topics.each do |topic_name|
  produce_many(topic_name, DT.uuids(5))
end

# Set offsets for all topics in origin consumer group
origin_offsets = topics.each_with_object({}) do |topic_name, hash|
  hash[topic_name] = { 0 => 3, 1 => 2 }
end

Karafka::Admin.seek_consumer_group(DT.consumer_group, origin_offsets)

ARGV[0] = 'parallel_segments'
ARGV[1] = 'distribute'

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('Distribution completed')
assert results.include?('successfully')

# Verify both segments received offsets for all topics
[segment1, segment2].each do |segment|
  offsets = Karafka::Admin.read_lags_with_offsets({ segment => topics })

  topics.each do |topic_name|
    assert_equal offsets[segment][topic_name][0][:offset], 3
    assert_equal offsets[segment][topic_name][1][:offset], 2
  end
end
