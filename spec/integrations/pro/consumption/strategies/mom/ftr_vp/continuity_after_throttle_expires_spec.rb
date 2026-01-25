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

# When we throttle with MoM enabled and we process longer than the throttle, it should not have
# any impact on the processing order. It should also not mark offsets in any way.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 4
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
    end

    # Exceed throttle time
    sleep(0.6)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    throttling(limit: 2, interval: 500)
    virtual_partitions(
      partitioner: ->(_msg) { rand(2) }
    )
  end
end

Thread.new do
  loop do
    produce(DT.topic, "1", partition: 0)

    sleep(0.1)
  rescue
    nil
  end
end

start_karafka_and_wait_until do
  DT[:offsets].size >= 20
end

previous = -1

# Order may be altered due to VPs
DT[:offsets].sort.each do |offset|
  assert_equal previous + 1, offset

  previous = offset
end
