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

# F07: `PerformanceTracker` accumulated a per-(topic, partition) samples array for every partition
# ever consumed and never released it on revoke/rebalance - a slow leak, unbounded under regex
# pattern subscriptions that keep discovering new topic names. It now evicts a partition's samples
# when the partition is revoked.
#
# Reproduced by consuming a partition (which records samples) and then letting the partition be
# revoked - the tracker must no longer hold the entry afterwards.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:sg_id] = topic.subscription_group.id
    DT[:consumed] << true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

def tracked_times
  Karafka::Pro::Instrumentation::PerformanceTracker.instance.instance_variable_get(:@processing_times)
end

# Reads the tracked entry without auto-vivifying the default-proc hashes
def tracked?(group_id, topic)
  group = tracked_times.fetch(group_id, nil)
  return false unless group

  topic_times = group.fetch(topic, nil)
  topic_times ? !topic_times.empty? : false
end

start_karafka_and_wait_until do
  next false if DT[:consumed].empty?

  # Sanity: the tracker recorded samples for our partition during consumption (without auto-
  # vivifying anything if it has not).
  DT[:populated] = tracked?(DT[:sg_id], DT.topic)

  true
end

# The tracker must actually have recorded our partition - otherwise the eviction assertion below
# would pass vacuously.
assert(DT[:populated], "performance tracker never recorded the consumed partition")

# After the partition was revoked (on shutdown), the tracker must have dropped its entry. Without
# the fix it retains it for the whole process lifetime.
assert(
  !tracked?(DT[:sg_id], DT.topic),
  "performance tracker did not evict the revoked partition: #{tracked_times.keys}"
)
