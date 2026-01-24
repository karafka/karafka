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

# Karafka should work as expected when having same matching used in multiple CGs.

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer1 < Karafka::BaseConsumer
  def consume
    DT[0] = 1
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DT[1] = 2
  end
end

draw_routes(create_topics: false) do
  pattern(:a, /#{DT.topic}/) do
    consumer Consumer1
  end

  consumer_group :b do
    pattern(:b, /#{DT.topic}/) do
      consumer Consumer2
    end
  end
end

start_karafka_and_wait_until do
  unless @created
    sleep(5)
    produce_many(DT.topic, DT.uuids(1))
    @created = true
  end

  DT.key?(0) && DT.key?(1)
end

assert_equal 1, DT[0]
assert_equal 2, DT[1]
