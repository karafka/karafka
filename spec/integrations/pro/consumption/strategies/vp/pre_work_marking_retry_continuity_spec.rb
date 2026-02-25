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

# After an error, in case we marked before the processing, we should just skip the broken and
# move on as we should just filter out broken one.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      mark_as_consumed(message)
      DT[:offsets] << message.offset

      raise if message.offset == 49
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(50))

extra_produced = false

start_karafka_and_wait_until do
  if DT[:offsets].size > 50
    true
  elsif DT[:offsets].size == 50 && !extra_produced
    extra_produced = true
    produce_many(DT.topic, DT.uuids(1))
    false
  else
    false
  end
end

assert_equal DT[:offsets].uniq.size, DT[:offsets].size
assert_equal DT[:offsets].sort, (0..50).to_a
