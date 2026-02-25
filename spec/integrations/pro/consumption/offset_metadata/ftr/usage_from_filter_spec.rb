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

# Karafka should allow for usage of the offset metadata from filters as well.
# Since filters can accept routing topic and partition reference from the builder, they can store
# them and use the fetcher to obtain needed offset metadata.
# This can allow them to use the pre-rebalance context awareness.

setup_karafka do |config|
  config.max_messages = 1
end

class Filter < Karafka::Pro::Processing::Filters::Base
  def initialize(topic, partition)
    super()
    @topic = topic
    @partition = partition
  end

  def apply!(_messages)
    DT[:metadata] << Karafka::Pro::Processing::OffsetMetadata::Fetcher.find(@topic, @partition)

    @applied = false
    @cursor = nil
  end

  def applied?
    false
  end

  def action
    :skip
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed!(message, message.offset.to_s)
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
    filter(->(topic, partition) { Filter.new(topic, partition) })
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:metadata].size >= 2
end

assert_equal ["", "0"], DT[:metadata]
