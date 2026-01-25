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

# Karafka should be able to easily consume all the messages from earliest (default) using multiple
# threads based on the used virtual partitioner. We should use more than one thread for processing
# of all the messages.
#
# This should also work as expected for pattern based topics.

setup_karafka do |config|
  config.concurrency = 10
  config.kafka[:"topic.metadata.refresh.interval.ms"] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[object_id] << message.offset
    end
  end
end

draw_routes(create_topics: false) do
  pattern(/.*#{DT.topic}/) do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

start_karafka_and_wait_until do
  sleep(1)

  unless @produced
    produce_many(DT.topic, DT.uuids(100))
    @produced = true
  end

  DT.data.values.sum(&:size) >= 100
end

# Since Ruby hash function is slightly nondeterministic, not all the threads may always be used
# but in general more than 5 need to be always
assert DT.data.size >= 5

# On average we should have similar number of messages
sizes = DT.data.values.map(&:size)
average = sizes.sum / sizes.size
# Small deviations may be expected
assert average >= 8
assert average <= 12

# All data within partitions should be in order
DT.data.each_value do |offsets|
  previous_offset = nil

  offsets.each do |offset|
    unless previous_offset
      previous_offset = offset
      next
    end

    assert previous_offset < offset
  end
end
