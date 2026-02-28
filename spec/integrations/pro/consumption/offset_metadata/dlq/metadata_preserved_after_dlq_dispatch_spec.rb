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

# After DLQ dispatch, offset metadata should be correctly persisted with the new offset
# position, ensuring metadata continuity across DLQ skip boundaries.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
  config.kafka[:"auto.commit.interval.ms"] = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:metadata] << offset_metadata(cache: false)

    store_offset_metadata(messages.first.offset.to_s)

    raise StandardError if messages.first.offset == 0
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:dlq] << message.headers["source_offset"].to_i
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer

    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 2
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:dlq].size >= 1 && DT[:metadata].size >= 5
end

# Offset 0 should have been dispatched to DLQ
assert_equal 0, DT[:dlq].first
# Metadata should have been collected across retries and recovery
assert DT[:metadata].size >= 5
