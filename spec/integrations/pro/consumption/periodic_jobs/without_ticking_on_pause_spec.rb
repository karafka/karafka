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

# When periodic jobs are configured not to tick when partition is paused we should not tick then
# Keep in mind, LRJ always pauses so you won't have ticking on it if this is set like this

setup_karafka do |config|
  config.max_wait_time = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:iterations] << true

    if DT[:iterations].size >= 5
      pause(messages.first.offset, 100_000_000)
      DT[:started] = Time.now.to_f
    end
  end

  def tick
    DT[:ticks] << Time.now.to_f
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic(
      interval: 100,
      during_pause: false
    )
  end
end

start_karafka_and_wait_until do
  if DT[:iterations].size < 5
    produce_many(DT.topic, DT.uuids(1))
    sleep(1)
  end

  DT[:iterations].size >= 5 && DT.key?(:started) && sleep(5)
end

DT[:ticks].each do |tick|
  assert tick <= DT[:started]
end
