# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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

ARGV[0] = "parallel_segments"
ARGV[1] = "distribute"

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?("Distribution completed")
assert results.include?("successfully")

# Verify both segments received offsets for all topics
[segment1, segment2].each do |segment|
  offsets = Karafka::Admin.read_lags_with_offsets({ segment => topics })

  topics.each do |topic_name|
    assert_equal offsets[segment][topic_name][0][:offset], 3
    assert_equal offsets[segment][topic_name][1][:offset], 2
  end
end
