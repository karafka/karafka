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

# When using transactions, we should be able to track the stored offset by taking the seek offset

setup_karafka do |config|
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

Karafka.monitor.subscribe('consumer.consuming.transaction') do |event|
  DT[:seeks] << event[:caller].seek_offset
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:done)

    transaction do
      producer.produce_async(topic: DT.topic, payload: rand.to_s)
      mark_as_consumed(messages.first, messages.first.offset.to_s)
    end

    DT[:metadata] << offset_metadata
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[:seeks].size >= 5
end

assert DT[:seeks].last >= 10
