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

# Fast jobs should also not have any problems (though not recommended) when running as lrj

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
  # We set it here that way not too wait too long on stuff
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end

    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << [message.headers['source_offset'].to_i, message.offset]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    dead_letter_queue topic: DT.topics[1]
    throttling(limit: 5, interval: 5_000)
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
    throttling(limit: 5, interval: 5_000)
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

payloads = DT.uuids(20)
produce_many(DT.topic, payloads)

start_karafka_and_wait_until do
  DT[0].size >= 20 && DT[1].size >= 10
end

# All messages moved to DLQ should have been present in the regular one
assert (DT[1].map(&:first) - DT[0]).empty?
# Each message should be present only once in the DLQ
assert_equal DT[1].uniq, DT[1]
# There should be many of them as we fail always
assert DT[1].size >= 10, DT[1]
