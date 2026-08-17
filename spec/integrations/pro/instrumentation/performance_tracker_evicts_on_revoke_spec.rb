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

# F07: `PerformanceTracker` accumulated a samples array for every partition ever consumed and
# never released it on revoke/rebalance - a slow leak, unbounded under regex pattern subscriptions
# that keep discovering new topic names. It now evicts a partition's samples when the partition is
# revoked.
#
# Observed entirely through the public `#processing_time_p95`: while consuming it reports the
# recorded p95 (> 0), and once the partition is revoked (on shutdown) the eviction makes it report
# 0 again. Without the fix the samples - and their non-zero p95 - would survive the revoke.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:sg_id] = topic.subscription_group.id
    # A small amount of work so the recorded processing time (and thus p95) is measurably > 0
    messages.each { DT[:consumed] << true }
    sleep(0.02)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

tracker = Karafka::Pro::Instrumentation::PerformanceTracker.instance

start_karafka_and_wait_until do
  # Wait until a sample has actually been recorded for our partition (the consumed event fires
  # after #consume returns), then capture the live p95 while the partition is still assigned.
  next false unless DT.key?(:sg_id)

  p95 = tracker.processing_time_p95(DT[:sg_id], DT.topic, 0)
  next false unless p95.positive?

  DT[:p95_while_assigned] = p95

  true
end

# Non-vacuous guard: the tracker really did record a non-zero p95 during consumption
assert DT[:p95_while_assigned].positive?, "performance tracker never recorded the consumed partition"

# After the partition was revoked (on shutdown) the samples are evicted, so the public p95 reports
# 0 again. Without the fix the samples would survive and p95 would still be > 0.
p95_after_revoke = tracker.processing_time_p95(DT[:sg_id], DT.topic, 0)

assert_equal(
  0,
  p95_after_revoke,
  "performance tracker did not evict the revoked partition (p95 still #{p95_after_revoke})"
)
