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

# When consumer uses patterns and same pattern matches the DLQ, messages may be self-consumed
# creating endless loop. Not something you want.

TOPIC_NAME = "it-not-funny-at-all-#{SecureRandom.uuid}".freeze

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << topic.name

    raise
  end
end

draw_routes(create_topics: false) do
  pattern(/#{TOPIC_NAME}/) do
    consumer Consumer

    dead_letter_queue(
      topic: "#{TOPIC_NAME}.dlq",
      max_retries: 1,
      independent: true
    )
  end
end

# No spec needed because finishing condition acts as a guard
start_karafka_and_wait_until do
  unless @created
    sleep(5)
    produce_many(TOPIC_NAME, DT.uuids(1))
    @created = true
  end

  DT[0].uniq.size >= 2
end
