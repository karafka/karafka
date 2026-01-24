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

# When using the DLQ with topic set to false, Karafka should not dispatch the message further but
# should apply the DLQ skipping logic anyhow.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError if messages.first.offset.zero?

    messages.each do |message|
      DT[:valid] << message.offset
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    DT[:dispatched] << true
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: false, max_retries: 0)
  end

  # This should never be reached
  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  !DT[:valid].empty?
end

assert_equal 1, DT[:errors].size
assert_equal [], DT[:dispatched]
assert !DT[:valid].empty?
