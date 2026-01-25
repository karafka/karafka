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

# If transaction finishes and the error is after it, it should not impact the offset nor the
# location where we retry

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.max_messages = 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    transaction do
      mark_as_consumed(messages.first, messages.first.offset.to_s)
    end

    if DT.key?(:raised)
      DT[:done] = true
    else
      DT[:raised] = true
      raise StandardError
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 1, DT[:offsets].count(0)
