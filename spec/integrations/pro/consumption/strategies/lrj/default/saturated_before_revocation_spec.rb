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

# When we have a LRJ job and revocation happens, non revocation aware LRJ should not cause a
# timeout because the revocation job is also non-blocking.

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.concurrency = 2
  config.max_messages = 1
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

events = []

Karafka::App.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "connection.client.poll.error"

  events << event
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:any] << object_id

    sleep(1) while DT[:done].empty?

    sleep(15)
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    long_running_job true
    manual_offset_management true
  end
end

produce(DT.topic, "1", partition: 0)
produce(DT.topic, "1", partition: 1)

def trigger_rebalance
  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  first = false

  10.times do
    message = consumer.poll(1_000)

    next unless message

    first = message.offset

    break
  end

  consumer.close

  first
end

start_karafka_and_wait_until do
  sleep(0.1) while DT[:any].uniq.size < 2

  trigger_rebalance

  DT[:done] << true

  sleep(15)

  true
end

assert events.empty?, events
