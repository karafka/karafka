# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka parallel segments collapse should work when there are multiple topics

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

segment1_offsets = topics.each_with_object({}) do |topic_name, hash|
  hash[topic_name] = { 0 => 3, 1 => 2 }
end

segment2_offsets = topics.each_with_object({}) do |topic_name, hash|
  hash[topic_name] = { 0 => 3, 1 => 2 }
end

Karafka::Admin.seek_consumer_group(segment1, segment1_offsets)
Karafka::Admin.seek_consumer_group(segment2, segment2_offsets)

ARGV[0] = 'parallel_segments'
ARGV[1] = 'collapse'

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?('Collapse completed')
assert results.include?('successfully')

offsets = Karafka::Admin.read_lags_with_offsets({ DT.consumer_group => topics })

topics.each do |topic_name|
  assert_equal offsets[DT.consumer_group][topic_name][0][:offset], 3
  assert_equal offsets[DT.consumer_group][topic_name][1][:offset], 2
end
