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

# Karafka should have a way to create long living iterators that wait for messages

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

Thread.new do
  loop do
    produce(DT.topic, "1")

    sleep(0.02)
  rescue
    nil
  end
end

iterator = Karafka::Pro::Iterator.new(
  { DT.topic => -1 },
  settings: { "enable.partition.eof": false },
  yield_nil: true
)

# Stop iterator when 100 messages are accumulated
limit = 100
buffer = []

iterator.each do |message|
  break if buffer.size >= limit

  # Message may be a nil when `yield_nil` is set to true
  buffer << message if message
end

assert_equal buffer.size, 100
