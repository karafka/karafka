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

# The iterator should use the group.id specified in the settings hash when provided.
# By default, the iterator uses its own admin group ID (not the routing-defined consumer group),
# but this can be overridden via the settings hash. This is useful when you want to:
# - Track iterator progress for resuming later
# - Use a specific consumer group for offset management
# - Share offset state between multiple iterator instances

setup_karafka

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      active false
    end
  end
end

# Produce 50 messages to the topic
produce_many(DT.topic, DT.uuids(50))

# Custom group ID for the iterator
custom_group_id = SecureRandom.uuid

# Settings with custom group.id
settings = {
  'group.id': custom_group_id,
  'auto.offset.reset': 'beginning'
}

# Topic with partition => true means resume from last committed offset
# On first run, this will start from beginning due to 'auto.offset.reset'
topics = { DT.topic => { 0 => true } }

# First iteration: consume 10 messages and mark them as consumed
iterator = Karafka::Pro::Iterator.new(topics, settings: settings)

count = 0
iterator.each do |message|
  count += 1
  DT[0] << message.offset
  iterator.mark_as_consumed(message)
  iterator.stop if count >= 10
end

assert_equal 10, count

# Verify that the custom group ID has stored offsets (offset 10 is next to consume)
results = Karafka::Admin.read_lags_with_offsets({ custom_group_id => [DT.topic] })
offset = results.fetch(custom_group_id).fetch(DT.topic)[0][:offset]
assert_equal 10, offset

# Verify that the routing-defined consumer group has NOT stored any offsets
# (proving the iterator didn't use it)
routing_results = Karafka::Admin.read_lags_with_offsets({ DT.consumer_group => [DT.topic] })
routing_offset = routing_results.fetch(DT.consumer_group).fetch(DT.topic)[0][:offset]
assert_equal(-1, routing_offset, 'Iterator should not use routing-defined consumer group')

# Second iteration: resume from where we left off using the same custom group ID
iterator = Karafka::Pro::Iterator.new(topics, settings: settings)

count = 0
iterator.each do |message|
  count += 1
  DT[1] << message.offset
  iterator.mark_as_consumed!(message)
  iterator.stop if count >= 10
end

assert_equal 10, count

# Verify we consumed offsets 10-19 (resuming from where we stopped)
assert_equal (10..19).to_a, DT[1]

# Verify the custom group ID now has offset 20
results = Karafka::Admin.read_lags_with_offsets({ custom_group_id => [DT.topic] })
offset = results.fetch(custom_group_id).fetch(DT.topic)[0][:offset]
assert_equal 20, offset

# Third iteration: start a NEW iterator without custom group.id
# This should use the default admin group and start from beginning
default_iterator = Karafka::Pro::Iterator.new(DT.topic)

count = 0
default_iterator.each do |message|
  count += 1
  DT[2] << message.offset
  default_iterator.stop if count >= 5
end

assert_equal 5, count
# Should start from offset 0 since it's using a different (default admin) group
assert_equal [0, 1, 2, 3, 4], DT[2]
