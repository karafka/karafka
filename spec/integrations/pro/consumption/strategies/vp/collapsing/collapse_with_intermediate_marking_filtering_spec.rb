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

# After we collapse, we should skip messages we marked as consumed, except those that were not
# processed.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise if message.offset == 49 && !collapsed?

      mark_as_consumed(message) if message.offset > 10

      DT[0] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    manual_offset_management(true)
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { (message.offset < 20 || message.offset == 49) ? 0 : 1 }
    )
  end
end

produce_many(DT.topic, DT.uuids(50))

start_karafka_and_wait_until do
  DT[0].size >= 50
end

assert_equal DT[0].uniq.size, DT[0].size
