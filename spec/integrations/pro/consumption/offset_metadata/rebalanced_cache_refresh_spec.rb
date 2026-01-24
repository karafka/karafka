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

# When rebalance occurs, even if we had cache, it should be invalidated

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed!(message, message.offset.to_s)
      DT[:metadata] << offset_metadata
    end

    unless @rebalanced
      @rebalanced = true
      DT[:trigger] = true
      sleep(5)
    end
  end
end

Thread.new do
  sleep(0.1) until DT.key?(:trigger)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)
  5.times { consumer.poll(500) }
  consumer.close
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:metadata].size >= 2
end

assert_equal %w[0 1], DT[:metadata]
