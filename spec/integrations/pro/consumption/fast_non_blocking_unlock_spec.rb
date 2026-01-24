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

# Because when we set time based locks that can bypass default ticking, we should be able to jump
# over ticking faster that the ticking interval
#
# We do not not instrument wait unlocks on the queue but since listener events are published, we
# can use next poll start to notice that it unlocks faster than the tick interval but slower than
# post-job immediate unlock

setup_karafka do |config|
  config.max_messages = 1
  config.concurrency = 1
  # If unlock is not working, this will make things hang
  config.internal.tick_interval = 1_000_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:ticks] << Time.now.to_f

    # Triggers the job queue state flow switch to the one that supports immediate timeouts
    unless @first_pause
      subscription_groups_coordinator.pause(topic.subscription_group, timeout: 0)
      @first_pause = true

      return
    end

    # Unlock fast
    subscription_groups_coordinator.pause(topic.subscription_group, timeout: 1_000)
  end
end

draw_routes do
  subscription_group :a do
    topic DT.topics[0] do
      consumer Consumer
    end
  end
end

produce_many(DT.topics[0], DT.uuids(50))

start_karafka_and_wait_until do
  DT[:ticks].size >= 10
end

previous = nil

DT[:ticks].each_with_index do |tick, index|
  if previous.nil? || index < 2
    previous = tick
    next
  end

  tick_distance = tick - previous

  assert tick_distance > 1
  assert tick_distance < 2

  previous = tick
end
