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

# When iterating over partitions and starting from different offsets, we should reach the end
# and data should be as expected.

setup_karafka

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    active false
  end
end

partitioned_elements = {}

2.times do |partition|
  elements = DT.uuids(20).map { |data| { value: data }.to_json }
  produce_many(DT.topic, elements, partition: partition)
  partitioned_elements[partition] = elements
end

partitioned_data = Hash.new { |h, v| h[v] = [] }

iterator = Karafka::Pro::Iterator.new(
  {
    DT.topic => { 0 => 0, 1 => 10 }
  }
)

iterator.each do |message|
  partitioned_data[message.partition] << message
end

assert_equal 2, partitioned_data.size

# for partition 0 we start from beginning
offset = 0
partitioned_data[0].each do |message|
  assert_equal offset, message.offset
  assert_equal message.raw_payload, partitioned_elements[0][offset]

  offset += 1
end

assert_equal 20, partitioned_elements[0].size

# for partition 1 we start from the middle
offset = 10
partitioned_data[1].each do |message|
  assert_equal offset, message.offset
  assert_equal message.raw_payload, partitioned_elements[1][offset]

  offset += 1
end

assert_equal 10, partitioned_data[1].size, partitioned_data[1].size
