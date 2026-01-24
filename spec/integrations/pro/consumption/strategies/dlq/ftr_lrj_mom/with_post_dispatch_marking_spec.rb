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

# When using manual offset management and not marking anything at all, we should not change
# offsets until DLQ as long as DLQ has an explicit post-error marking (which is not the default)

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 5
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Mark so throttle won't start from 0
      mark_as_consumed(message) if message.offset == 4

      raise StandardError if message.offset == 5

      DT[0] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue topic: DT.topics[1], max_retries: 1, mark_after_dispatch: true
    long_running_job true
    manual_offset_management true
    throttling(limit: 5, interval: 5_000)
  end
end

payloads = DT.uuids(50)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

assert_equal 6, fetch_next_offset
