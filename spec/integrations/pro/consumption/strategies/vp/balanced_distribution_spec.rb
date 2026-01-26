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

# When using Virtual Partitions with balanced distribution, we should ensure that:
# 1. Messages with the same key are processed together
# 2. Larger groups are processed first
# 3. Messages within each group maintain their order
# 4. Work is distributed across available workers
#
# Please note, that cross-batch VP assignment is not guaranteed with this distribution strategy.

setup_karafka do |config|
  config.concurrency = 3
  config.max_messages = 11
  config.max_wait_time = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    # We skip on first batch because the cost computation is not accurate until
    # we get p95 from first batch processing
    unless @first_batch
      @first_batch = true
      return
    end

    messages.each do |message|
      DT[object_id] << [message.raw_key, message.offset]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*_args) { VpStabilizer.new(11) }
    virtual_partitions(
      max_partitions: 3,
      partitioner: ->(msg) { msg.raw_key },
      distribution: :balanced
    )
  end
end

# Create messages with different keys and sizes
# Key 'a' has 5 messages
# Key 'b' has 3 messages
# Key 'c' has 2 messages
# Key 'd' has 1 message
# Key 'e' has 1 message

2.times do
  Karafka.producer.produce_many_sync(
    [
      { topic: DT.topic, payload: "1", key: "a" },
      { topic: DT.topic, payload: "2", key: "a" },
      { topic: DT.topic, payload: "3", key: "a" },
      { topic: DT.topic, payload: "4", key: "a" },
      { topic: DT.topic, payload: "5", key: "b" },
      { topic: DT.topic, payload: "6", key: "b" },
      { topic: DT.topic, payload: "7", key: "b" },
      { topic: DT.topic, payload: "8", key: "c" },
      { topic: DT.topic, payload: "9", key: "c" },
      { topic: DT.topic, payload: "10", key: "d" },
      { topic: DT.topic, payload: "11", key: "e" },
      { topic: DT.topic, payload: "12", key: "a" }
    ]
  )
end

start_karafka_and_wait_until do
  DT.data.values.sum(&:size) >= 11
end

# Verify that messages with the same key were processed together
DT.data.values.each do |messages|
  messages.group_by(&:first).each do |key, group|
    # Check that offsets are in order within each group
    offsets = group.map(&:last)
    assert_equal offsets, offsets.sort, "Messages for key '#{key}' are not in order"
  end
end

values = DT.data.sort_by { |object_id, _| object_id }.to_h.values

EXPECTED_SIZES = [5, 3].freeze

values.map(&:size).each do |size|
  assert EXPECTED_SIZES.include?(size), size
end

# Verify that we used all available workers
assert_equal 3, DT.data.size

# Verify that all messages were processed
assert_equal 11, DT.data.values.sum(&:size)
