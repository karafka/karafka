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

# When we consume data and several times we loose and regain partition, there should be
# continuity in what messages we pick up even if rebalances happens multiple times. This should
# apply to using LRJ as well.
#
# We may re-fetch certain messages but none should be skipped

setup_karafka do |config|
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep 5

    messages.each do |message|
      DT[:offsets] << message.offset

      return unless mark_as_consumed!(message)
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

MESSAGES = DT.uuids(1_000)

# We need a second producer to trigger the rebalances
Thread.new do
  sleep(10)

  10.times do
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topic)
    sleep(2)
    consumer.close
    sleep(1)
  end

  DT[:rebalanced] << true
end

i = 0

start_karafka_and_wait_until do
  10.times do
    produce(DT.topic, MESSAGES[i])
    i += 1
  end

  sleep(1)

  DT.key?(:rebalanced)
end

previous = nil

# They need to be in order one batch after another
DT[:offsets].uniq.each do |offset|
  unless previous
    previous = offset
    next
  end

  assert_equal previous + 1, offset

  previous = offset
end
