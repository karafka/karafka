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

# We should be able to have part of topics with periodics in the same SG

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    DT[:ticks] << topic.name
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    periodic interval: 100
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  DT[:ticks].size >= 6
end

assert_equal 1, DT[:ticks].uniq.size
