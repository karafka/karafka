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

# When user pauses and marks by himself, we should not deal with this and let him do this.

setup_karafka do |config|
  config.max_messages = 50
  config.pause.timeout = 2_000
  config.pause.max_timeout = 2_000
  config.pause.with_exponential_backoff = false
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:paused] << messages.first.offset
    DT[:last] << messages.last.offset

    pause(messages.first.offset, 1_000)

    mark_as_consumed(messages.last)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
  end
end

produce_many(DT.topic, DT.uuids(200))

start_karafka_and_wait_until do
  DT[:paused].size >= 3
end

assert_equal fetch_next_offset, DT[:last].max + 1
