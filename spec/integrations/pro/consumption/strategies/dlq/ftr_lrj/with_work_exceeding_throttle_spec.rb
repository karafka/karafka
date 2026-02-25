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

# When doing work that is exceeding timeouts, we should not throttle. Instead we need to seek
# to the first throttled message and just move on. DLQ should not interact with this in any way.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end

    sleep(2)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    long_running_job true
    throttling(
      limit: 2,
      interval: 1_000
    )
  end
end

# This should never happen because throttle expires and we seek to the correct location
Karafka.monitor.subscribe "filtering.throttled" do
  raise
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  # This needs to run for a while as on slow CIs things pick up slowly
  sleep(15)
end

# All messages should be received and seek should work correctly
assert_equal DT[0], (0...DT[0].size).to_a
