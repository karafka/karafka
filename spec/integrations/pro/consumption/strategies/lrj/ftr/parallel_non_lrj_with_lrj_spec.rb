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

# When using LRJ within a consumer group with other non-LRJ, the LRJ should be running while other
# jobs are consumed and they should not wait (as long as enough workers) and throttling should
# not cause any problems

setup_karafka do |config|
  config.max_messages = 1
  config.concurrency = 5
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class LrjConsumer < Karafka::BaseConsumer
  def consume
    producer.produce_sync(topic: DT.topics[1], payload: "1")
    sleep(15)
    DT[:done_time] << Time.now
  end
end

class RegularConsumer < Karafka::BaseConsumer
  def consume
    DT[:regular_time] << Time.now
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer LrjConsumer
    long_running_job true
    throttling(limit: 1, interval: 5_000)
  end

  topic DT.topics[1] do
    consumer RegularConsumer
  end
end

produce(DT.topics[0], "1")

start_karafka_and_wait_until do
  DT.key?(:done_time)
end

assert DT[:regular_time][0] < DT[:done_time][0]
