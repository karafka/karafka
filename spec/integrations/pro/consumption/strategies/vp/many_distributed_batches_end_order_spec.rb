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

# When consuming data with virtual partitions from many batches, the order of messages in between
# the single partition batches should be preserved.

setup_karafka do |config|
  config.concurrency = 10
end

Karafka.monitor.subscribe('connection.listener.fetch_loop.received') do |event|
  next if event.payload[:messages_buffer].empty?

  DT[:batches] << []
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:batches].last << [message.offset]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

start_karafka_and_wait_until do
  if DT[:batches].sum(&:size) < 1000
    produce_many(DT.topic, DT.uuids(100))
    sleep(1)
    false
  else
    true
  end
end

# Sort messages from each of the batches
DT[:batches].map! do |batch|
  batch.sort_by!(&:first)
end

previous = nil

# They need to be in order one batch after another
DT[:batches].flatten.each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
