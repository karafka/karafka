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

# When using separate subscription groups, each should have it's own underlying client and should
# operate independently for data fetching and consumption

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:clients] << client.object_id
    DT[:consumers] << object_id
  end
end

draw_routes do
  subscription_group :sg do
    multiplexing(max: 5)

    topic DT.topic do
      config(partitions: 10)
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until do
  10.times do |i|
    produce_many(DT.topic, DT.uuids(10), partition: i)
  end

  sleep(1)

  DT[:clients].uniq.size >= 5 && DT[:consumers].uniq.size >= 5
end

assert_equal 5, DT[:clients].uniq.size
assert DT[:consumers].uniq.size >= 5
