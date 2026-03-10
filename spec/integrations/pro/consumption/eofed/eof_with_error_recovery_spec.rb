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

# When a consumer encounters an error, retries, and then hits EOF, the eofed callback
# should be invoked after successful processing and recovery.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    if DT[:raised].empty?
      DT[:raised] << true
      raise StandardError
    end
  end

  def eofed
    DT[:eofed] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed true
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:eofed].size >= 1
end

# All offsets should have been processed
assert_equal (0..4).to_a, DT[:offsets].uniq.sort
# eofed should have been called after recovery
assert DT[:eofed].size >= 1
# There should have been an error
assert DT[:raised].size >= 1
