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

# When offsets are part of producer transactions, they will no longer appear in the consumer
# `statistics.emitted` events and should be compensated via Karafka instrumentation.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

Karafka.monitor.subscribe('statistics.emitted') do |event|
  DT[:statistics] << event[:statistics]
end

class Consumer < Karafka::BaseConsumer
  def consume
    transaction do
      mark_as_consumed(messages.last)
    end

    DT[:counts] << true
  end
end

draw_routes(Consumer)
produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:statistics].size >= 100 && DT[:counts].size >= 100
end

p_stats = DT[:statistics].last['topics'][DT.topic]['partitions']['0']

assert_equal(-1, p_stats['consumer_lag'])
assert_equal(-1, p_stats['consumer_lag_stored'])
