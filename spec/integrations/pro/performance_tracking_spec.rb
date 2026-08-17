# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka should track consumption rate metrics when pro
# This metrics tracker is then used internally for optimization purposes

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 2
end

TOPICS = DT.topics.first(5)

# Simulated different performance for different topics
MESSAGE_SPEED = TOPICS.map.with_index { |topic, index| [topic, index] }.to_h

class Consumer < Karafka::BaseConsumer
  def consume
    # Samples are scoped by subscription group id, so we capture the one backing this topic to
    # read the matching p95 later
    DT[:sg_ids][messages.metadata.topic] = topic.subscription_group.id

    # We add 10ms per message to make sure that the metrics tracking track it as expected
    messages.each do
      DT[0] << true

      # Sleep needs seconds not ms
      sleep MESSAGE_SPEED.fetch(messages.metadata.topic) / 1_000.0
    end
  end
end

draw_routes do
  TOPICS.each do |topic_name|
    topic topic_name do
      consumer Consumer
    end
  end
end

DT[:sg_ids] = {}

TOPICS.each do |topic_name|
  produce_many(topic_name, DT.uuids(10))
end

start_karafka_and_wait_until do
  next false unless DT[0].size >= 50

  # Capture p95 while the partitions are still assigned. The samples are per-partition runtime
  # metrics that are evicted when a partition is revoked (including on shutdown), so they must be
  # read during processing rather than after the consumer has stopped.
  tracker = Karafka::Pro::Instrumentation::PerformanceTracker.instance
  DT[:p95] = TOPICS.map do |topic_name|
    [topic_name, tracker.processing_time_p95(DT[:sg_ids].fetch(topic_name), topic_name, 0)]
  end.to_h

  true
end

TOPICS.each do |topic_name|
  p95 = DT[:p95].fetch(topic_name)

  message_speed = MESSAGE_SPEED.fetch(topic_name)

  assert p95 >= message_speed, "Expected #{p95} to be gteq: #{message_speed}"
  # We add 25ms to compensate for slow ci
  assert p95 <= message_speed + 25, "Expected #{p95} to be lteq: #{message_speed + 25}"
end
