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

# Karafka Web should handle high-concurrency DLQ message dispatching without deadlocking,
# ensuring tracking data is properly synchronized across many partitions

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
  config.concurrency = 20
  config.pause.timeout = 100
  config.pause.max_timeout = 100
  config.pause.with_exponential_backoff = false
end

setup_web do |config|
  config.tracking.interval = 1_000
  config.tracking.consumers.sync_threshold = 1
end

Karafka.monitor.subscribe('error.occurred') do
  DT[:errors] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    config(partitions: 100)
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 0
    )
  end
end

produce_many(DT.topics[0], DT.uuids(10_000))

start_karafka_and_wait_until do
  DT[:errors].size >= 1_000
end
