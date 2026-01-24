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

# When Karafka encounters messages that are too old, it should skip them
# We simulate this by having short ttl and delaying processing to build up a lag

setup_karafka { |config| config.max_messages = 5 }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [
        message.offset,
        Time.now.utc - message.timestamp
      ]
    end

    sleep(0.2)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # 1 second
    expire_in(1_000)
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(5))

  DT[0].size >= 50
end

# None of them should be older than 1 second
# Messages here can be slightly older than 1 second because there may be a distance in between the
# moment we filtered and the moment we're processing. That is why we're adding 500 ms
# We add 500ms because 200ms was not enough for slow CI with hiccups
assert(DT[0].map(&:last).all? { |age| age < 1.5 })

previous = nil
gap = false

# There should be skips in messages
DT[0].map(&:first).each do |offset|
  unless previous
    previous = offset
    next
  end

  gap = true if offset - previous > 1

  previous = offset
end

assert gap
