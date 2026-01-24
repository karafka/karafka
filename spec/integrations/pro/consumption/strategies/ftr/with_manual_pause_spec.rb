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

# Karafka should favour a manual pause over throttling and take appropriate action when the
# pause has expired. So if we've reached throttling threshold and paused, after the manual pause
# is over, we should pause and not process

# We also should not have any duplicates and processing should be smooth

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset

      pause(messages.last.offset + 1, 500) if DT[0].size == 5
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    throttling(
      limit: 5,
      interval: 5_000
    )
  end
end

elements = DT.uuids(100)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

assert_equal DT[0], (0...DT[0].size).to_a
