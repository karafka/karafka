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

# When using virtual partitions with eof, each VP should receive its own `#eofed` execution.

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
  end

  def eofed
    DT[:eofed] << object_id
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    eofed true
    virtual_partitions(
      partitioner: lambda(&:raw_payload)
    )
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(100))
  sleep(5)

  DT[:eofed].uniq.size >= 8
end
