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

# Karafka should throttle and wait also on topics that are detected via patterns later on

setup_karafka do |config|
  config.kafka[:"topic.metadata.refresh.interval.ms"] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(create_topics: false) do
  pattern(/#{DT.topic}/) do
    consumer Consumer
    throttling(
      limit: 2,
      interval: 60_000
    )
  end
end

elements = DT.uuids(20)

start_karafka_and_wait_until do
  sleep(5)

  produce_many(DT.topic, elements)

  # This needs to run for a while as on slow CIs things pick up slowly
  sleep(15)
end

assert_equal elements[0..1], DT[0]
