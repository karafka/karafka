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

ARGV[0] = "parallel_segments"
ARGV[1] = "distribute"

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?("Distribution completed")
assert results.include?("successfully")

# Verify all segments received the offsets
segments.each do |segment|
  offsets = Karafka::Admin.read_lags_with_offsets({ segment => [DT.topic] })
  assert_equal 5, offsets[segment][DT.topic][0][:offset]
  assert_equal 7, offsets[segment][DT.topic][1][:offset]
  assert_equal 3, offsets[segment][DT.topic][2][:offset]
  assert_equal 9, offsets[segment][DT.topic][3][:offset]
end
