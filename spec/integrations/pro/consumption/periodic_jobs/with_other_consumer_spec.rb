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

# When periodic ticking is on but other consumers have some partitions, we should not tick on them
# as they are not assigned to us

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def tick
    DT[:ticks] << messages.metadata.partition
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    periodic true
  end
end

# Running this first will ensure we get one partition on second consumer first
consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topic)

10.times do
  consumer.poll(100)
  sleep(0.5)
end

start_karafka_and_wait_until do
  DT[:ticks].size >= 10
end

consumer.close

assert_equal 1, DT[:ticks].uniq.size
