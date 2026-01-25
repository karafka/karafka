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

# We should be able to get the insights and use them via the API when they are defined
# In Pro despite extra option, should behave same as in OSS when no forced required

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:stats] << statistics
    DT[:stats] << insights
    DT[:stats_exist] << statistics?
    DT[:stats_exist] << insights?
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    inline_insights(true)
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:stats) && DT[:stats_exist].include?(true) && !DT[:stats].last.empty?
end

assert_equal 0, DT[:stats].last["partition"]
