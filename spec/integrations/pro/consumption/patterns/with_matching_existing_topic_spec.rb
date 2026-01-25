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

# Karafka should be able to match existing topic with pattern when starting processing and given
# topic already exists

setup_karafka do |config|
  config.kafka[:"topic.metadata.refresh.interval.ms"] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] = true
  end
end

draw_routes do
  pattern(/#{DT.topic}/) do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(0)
end

# No assertions needed. If works, won't hang.
