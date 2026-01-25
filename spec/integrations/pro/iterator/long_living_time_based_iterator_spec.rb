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

# Karafka should be able to exit from iterator even if no more messages are being shipped

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

produce(DT.topic, "1")

iterator = Karafka::Pro::Iterator.new(
  { DT.topic => -1 },
  settings: { "enable.partition.eof": false },
  yield_nil: true
)

# Stop if there were no messages for longer than 5 seconds
last_timestamp = Time.now
iterator.each do |message|
  last_timestamp = message.timestamp if message

  break if (Time.now - last_timestamp) >= 5
end

assert (Time.now - last_timestamp) >= 5
