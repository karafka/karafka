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

# In case our main producer is not transactional or for any other reason, we should be able to
# inject a transactional one and use it if we want.

setup_karafka

TRANSACTIONAL_PRODUCER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.kafka[:"transactional.id"] = SecureRandom.uuid
  producer_config.logger = Karafka::App.config.logger
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    DT[:before_producer] = producer

    # Without an injected producer this would not work as the default producer is not transactional
    transaction(TRANSACTIONAL_PRODUCER) do
      produce_async(topic: DT.topic, payload: rand.to_s)
      DT[:during_producer] = producer
      producer.produce_async(topic: DT.topic, payload: rand.to_s)
      mark_as_consumed(messages.first, messages.first.offset.to_s)
    end

    DT[:after_producer] = producer
    DT[:metadata] << offset_metadata
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management(true)
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal "0", DT[:metadata].first
assert_equal Karafka.producer, DT[:before_producer]
assert_equal TRANSACTIONAL_PRODUCER, DT[:during_producer]
assert_equal Karafka.producer, DT[:after_producer]
