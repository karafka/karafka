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

# Karafka should mark correctly the final offset of collective group upon finish

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1000
  config.concurrency = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { DT[0] << true }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    max_messages 1000
    long_running_job true
    dead_letter_queue topic: DT.topics[1], max_retries: 4
    virtual_partitions(
      partitioner: ->(_) { rand(1000) }
    )
  end
end

produce_many(DT.topic, DT.uuids(1000))

start_karafka_and_wait_until do
  DT[0].size >= 1000
end

assert_equal 1000, fetch_next_offset
