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

# When using single DLQ to handle errors from multiple topics, the dispatched message key should
# be preserved and consistent piping should be used.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [message.key, message.headers['source_partition']]
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    config(partitions: 100)
    consumer Consumer
    dead_letter_queue(topic: DT.topics[2], max_retries: 0)
  end

  topic DT.topics[1] do
    config(partitions: 100)
    consumer Consumer
    dead_letter_queue(topic: DT.topics[2], max_retries: 0)
  end

  topic DT.topics[2] do
    consumer DlqConsumer
  end
end

100.times do |i|
  elements = DT.uuids(10)
  produce_many(DT.topics[0], elements, partition: i, key: i.to_s)
  produce_many(DT.topics[1], elements, partition: i, key: i.to_s)
end

start_karafka_and_wait_until do
  DT[0].size >= 20
end

DT[0].each do |key|
  assert_equal key[0], key[1]
end

assert DT[0].map(&:first).uniq.size > 1
