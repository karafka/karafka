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

# When stored metadata exists, it should be used in the DLQ flow.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
  config.kafka[:"auto.commit.interval.ms"] = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:metadata] << offset_metadata(cache: false)

    store_offset_metadata(messages.first.offset.to_s)

    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer

    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 2
    )
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:metadata].size >= 10
end

assert_equal ["", "", "", 0, 0, 0, 1, 1, 1, 2].map(&:to_s), DT[:metadata][0..9]
