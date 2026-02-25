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

# When iterating over the topics, we should be able to use the pause current to stop only the
# current topic partition processing

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end

  topic DT.topics[1] do
    active false
  end
end

partitioned_elements = {}

2.times do |index|
  topic = DT.topics[index]

  elements = DT.uuids(20).map { |data| { value: data }.to_json }
  produce_many(topic, elements)
  partitioned_elements[topic] = elements
end

partitioned_data = Hash.new { |h, v| h[v] = [] }

iterator = Karafka::Pro::Iterator.new(
  [DT.topics[0], DT.topics[1]]
)

iterator.each do |message, internal_iterator|
  if message.topic == DT.topics[0] && message.offset == 10
    internal_iterator.stop_current_partition

    next
  end

  partitioned_data[message.topic] << message
end

assert_equal partitioned_data.size, 2

# All data should be in order for the rest
partitioned_data.each do |partition, messages|
  offset = 0

  messages.each do |message|
    assert_equal offset, message.offset
    assert_equal message.raw_payload, partitioned_elements[partition][offset]

    offset += 1
  end

  assert_equal messages.size, (messages.first.topic == DT.topics[0]) ? 10 : 20
end
