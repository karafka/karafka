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

# If we mark virtual offsets that cannot be materialized to a state, we should start from beginning
# on errors. Throttling should not impact it in any way

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 500
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    # Try marking a fake seek offset
    mark_as_consumed Karafka::Messages::Seek.new(topic.name, partition, 750)

    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    throttling(limit: 50, interval: 250)
    virtual_partitions(
      partitioner: ->(_msg) { rand(9) }
    )
  end
end

produce_many(DT.topic, DT.uuids(1000))

start_karafka_and_wait_until do
  DT[:offsets].size > 500
end

assert DT[:offsets].count(0) > 1
