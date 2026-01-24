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

# We should be able to resume from ticking

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume] << messages.last.offset

    # This will ensure we won't resume automatically
    pause(:consecutive, 1_000_000_000)
  end

  def tick
    resume
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

produce_many(DT.topic, DT.uuids(10))

# If resume from ticking will not work, this will hang
start_karafka_and_wait_until do
  DT[:consume].size >= 3
end

assert_equal [0, 1, 2], DT[:consume][0..2]
