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

# We should be able to lock in a non-blocking fashion our subscription group (or any other)
# and resume it from a periodic job on a different group
#
# Note: since we do not run periodics on the same go as a job, we cannot unlock from the same
# group. Time based locks are a different case covered in a different spec.

setup_karafka do |config|
  config.max_messages = 1
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT[1].size >= 10
      DT[:locks] << true

      subscription_groups_coordinator.pause(
        topic.subscription_group
      )

      DT[:group] = topic.subscription_group
    end

    DT[0] << Time.now.to_f
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    DT[1] << Time.now.to_f
  end

  def tick
    return unless DT[1].size >= 10
    return unless DT.key?(:group)
    return if @unlocked

    subscription_groups_coordinator.resume(DT[:group])
    @unlocked = true
  end
end

draw_routes do
  subscription_group :a do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  subscription_group :b do
    topic DT.topics[1] do
      consumer Consumer2
      periodic true
    end
  end
end

produce_many(DT.topics[0], DT.uuids(10))
produce_many(DT.topics[1], DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 10 && DT[1].size >= 10
end

# All events except the first one should come after all events from the second topic
DT[1..].each do |time|
  assert time > DT[1].last
end
