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

# When Karafka delays processing and we have only old messages, there should be no pausing or
# seeking and we should just process

setup_karafka { |config| config.max_messages = 10 }

class Listener
  def on_filtering_seek(_)
    DT[:unexpected] << true
  end

  def on_filtering_throttled(_)
    DT[:unexpected] << true
  end
end

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << [
        message.offset,
        message.timestamp
      ]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # 2 seconds
    delay_by(2_000)
  end
end

produce_many(DT.topic, DT.uuids(50))

sleep(2)

start_karafka_and_wait_until do
  DT[0].size >= 50
end

assert DT[:unexpected].empty?

# All should be delivered and all should be old enough
previous = -1

DT[0].each do |offset, timestamp|
  assert_equal previous + 1, offset
  previous = offset

  assert Time.now.utc - timestamp > 2
end
