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

# End-to-end two-step migration workflow on a multi-broker cluster:
# 1. Read committed offsets via Recovery (bypasses coordinator)
# 2. Verify the target group maps to a different coordinator (different broker)
# 3. Write offsets to target group via ConsumerGroups.seek
# 4. Verify offsets match via both Recovery and standard Admin APIs

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 3)
  end

  topic DT.topics[1] do
    active false
  end
end

SOURCE_GROUP = SecureRandom.uuid

# Commit offsets for the source group across multiple topics and partitions
Karafka::Admin.seek_consumer_group(
  SOURCE_GROUP,
  {
    DT.topics[0] => { 0 => 15, 1 => 30, 2 => 45 },
    DT.topics[1] => { 0 => 100 }
  }
)

sleep(2)

# Find a target group that maps to a different __consumer_offsets partition (different coordinator)
source_partition = Karafka::Admin::Recovery.offsets_partition_for(SOURCE_GROUP)
source_coord = Karafka::Admin::Recovery.coordinator_for(SOURCE_GROUP)

TARGET_GROUP = (0..10_000).lazy.map { |i| "target-#{i}" }.find do |name|
  Karafka::Admin::Recovery.offsets_partition_for(name) != source_partition
end

assert TARGET_GROUP, "Could not find a target group on a different partition"

target_coord = Karafka::Admin::Recovery.coordinator_for(TARGET_GROUP)

# On a multi-broker cluster, different partitions are likely on different brokers
# (not guaranteed, but informational)
if source_coord[:broker_id] != target_coord[:broker_id]
  # Good — source and target are on different brokers, simulating real recovery
end

# Step 1: Read committed offsets via Recovery (bypasses coordinator)
recovered = Karafka::Admin::Recovery.read_committed_offsets(
  SOURCE_GROUP,
  lookback_ms: 60 * 1_000
)

assert_equal({ 0 => 15, 1 => 30, 2 => 45 }, recovered[DT.topics[0]])
assert_equal({ 0 => 100 }, recovered[DT.topics[1]])

# Step 2: Write recovered offsets to the target group
Karafka::Admin::ConsumerGroups.seek(TARGET_GROUP, recovered)

# Step 3: Verify via Recovery that the target group has the same offsets
target_recovered = Karafka::Admin::Recovery.read_committed_offsets(
  TARGET_GROUP,
  lookback_ms: 60 * 1_000
)

assert_equal recovered[DT.topics[0]], target_recovered[DT.topics[0]]
assert_equal recovered[DT.topics[1]], target_recovered[DT.topics[1]]

# Step 4: Verify via standard Admin API
lags = Karafka::Admin.read_lags_with_offsets(
  { TARGET_GROUP => [DT.topics[0], DT.topics[1]] }
)

assert_equal 15, lags[TARGET_GROUP][DT.topics[0]][0][:offset]
assert_equal 30, lags[TARGET_GROUP][DT.topics[0]][1][:offset]
assert_equal 45, lags[TARGET_GROUP][DT.topics[0]][2][:offset]
assert_equal 100, lags[TARGET_GROUP][DT.topics[1]][0][:offset]
