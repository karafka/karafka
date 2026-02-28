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

# When we operate in a collapsed mode, transactions should operate in a linear fashion

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError unless collapsed?

    DT[:done] = true

    transaction do
      mark_as_consumed(messages.first, "test-metadata")
    end
  end

  def shutdown
    DT[:metadata] << offset_metadata(cache: false)
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter VpStabilizer
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next }
    )
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal "test-metadata", DT[:metadata].last
assert_equal 1, fetch_next_offset
