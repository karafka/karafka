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

# The PerformanceTracker is a process-wide singleton. When two consumer groups consume the same
# topic name, their samples must be kept independent (scoped by subscription group), otherwise a
# fast group and a slow group sharing the same topic would pollute each other's measurements - and
# revoking a partition in one group would drop samples the other group is still using.
#
# Here two consumer groups consume the same topic at very different speeds. Each group's p95 must
# reflect only its own work: were the samples shared, both reads would collapse to the same value.

setup_karafka do |config|
  config.max_messages = 1
end

FAST_GROUP = DT.groups[0]
SLOW_GROUP = DT.groups[1]

class FastConsumer < Karafka::BaseConsumer
  def consume
    DT[:fast_sg] = topic.subscription_group.id
    messages.each { DT[:fast] << true }
  end
end

class SlowConsumer < Karafka::BaseConsumer
  def consume
    DT[:slow_sg] = topic.subscription_group.id

    messages.each do
      DT[:slow] << true
      # ~20ms per message so this group's p95 is clearly above the fast group's
      sleep(0.02)
    end
  end
end

draw_routes do
  consumer_group FAST_GROUP do
    topic DT.topic do
      consumer FastConsumer
    end
  end

  consumer_group SLOW_GROUP do
    topic DT.topic do
      consumer SlowConsumer
    end
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  next false unless DT[:fast].size >= 20
  next false unless DT[:slow].size >= 20

  # Capture p95 while partitions are still assigned (samples are evicted on revoke/shutdown)
  tracker = Karafka::Pro::Instrumentation::PerformanceTracker.instance
  DT[:fast_p95] = tracker.processing_time_p95(DT[:fast_sg], DT.topic, 0)
  DT[:slow_p95] = tracker.processing_time_p95(DT[:slow_sg], DT.topic, 0)

  true
end

# The two groups consume the same topic but live in different subscription groups
assert DT[:fast_sg] != DT[:slow_sg], "expected distinct subscription groups for the two groups"

# The slow group must have recorded its (slow) samples - guards against a vacuous comparison
assert DT[:slow_p95].positive?, "slow group p95 should have been recorded"

# Independent measurements: the slow group's p95 reflects its ~20ms sleeps while the fast group's
# stays low. If the samples collided into a single shared array, both reads would be (near) equal.
assert(
  DT[:slow_p95] > DT[:fast_p95],
  "expected slow group p95 (#{DT[:slow_p95]}) to exceed fast group p95 (#{DT[:fast_p95]})"
)
