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

# Karafka should track offsets in transaction but only mark last on success

setup_karafka do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    return seek(0) unless messages.size == 100

    return if DT.key?(:done)

    transaction do
      messages.each do |message|
        mark_as_consumed(message, message.offset.to_s)
      end
    end

    DT[:metadata] << offset_metadata
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal "99", DT[:metadata].first

# +1 from 99 because of the transaction marker
assert_equal 100, fetch_next_offset
