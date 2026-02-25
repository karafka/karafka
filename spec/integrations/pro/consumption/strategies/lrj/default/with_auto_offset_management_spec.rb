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

# When using automatic offset management, we should end up with offset committed after the last
# message and we should "be" there upon returning to processing

setup_karafka do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.last.offset
    # We sleep here so we don't end up consuming so many messages, that the second consumer would
    # hang as there would be no data for him
    sleep(1)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT.key?(0)
end

assert_equal DT[0].last + 1, fetch_next_offset
