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

# When a transaction is aborted, it should also fire the consuming event as abort similar to
# ActiveRecord transaction does not propagate and is handled internally, thus no error.

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

Karafka.monitor.subscribe('consumer.consuming.transaction') do
  DT[:occurred] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    transaction do
      mark_as_consumed(messages.last)
      DT[:done] = true

      raise(WaterDrop::AbortTransaction)
    end

    DT[:seek_offset] = seek_offset
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 0, fetch_next_offset
assert DT.key?(:occurred)
assert_equal 0, DT[:seek_offset]
