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

# When we mark as consumed outside of the transactional block but by using the transactional
# producer, in a case where we were not able to finalize the transaction it should not raise an
# error but instead should return false like the non-transactional one. This means we no longer
# have ownership of this partition.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] = true
    sleep(11)
    DT[:marking_result] = mark_as_consumed(messages.last)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(2))

start_karafka_and_wait_until do
  DT.key?(:marking_result)
end

assert_equal false, DT[:marking_result]
