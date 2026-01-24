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

# In case transactional offset dispatch on post-error happens, Karafka should retry processing
# again and again.

setup_karafka(
  allow_errors: %w[consumer.consume.error consumer.after_consume.error]
) do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

module Patch
  # We overwrite it to simulate a transactional error on the potential DLQ dispatch
  def transaction(*_args)
    raise StandardError
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless @enriched
      singleton_class.prepend Patch
      @enriched = true
    end

    DT[:offsets] << messages.first.offset

    raise StandardError
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 2,
      transactional: true
    )
  end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:type] == 'consumer.consume.error'

  DT[:errors] << 1
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:errors].size >= 10
end

assert_equal DT[:offsets].uniq, [0]
