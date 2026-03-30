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

# End-to-end two-step migration workflow on a multi-broker cluster:
# 1. Read committed offsets via Recovery (bypasses coordinator)
# 2. Verify the target group maps to a different coordinator
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

# Try up to 100_000 names to find one on a different partition
target_group = nil

100_000.times do |i|
  candidate = "target-#{i}"
  next if Karafka::Admin::Recovery.offsets_partition_for(candidate) == source_partition

  target_group = candidate
  break
end

# If we couldn't find one (e.g. only 1 partition), skip test gracefully
exit 0 unless target_group

# Step 1: Read committed offsets via Recovery (bypasses coordinator)
recovered = Karafka::Admin::Recovery.read_committed_offsets(
  SOURCE_GROUP,
  last_committed_at: Time.now - 60
)

assert_equal({ 0 => 15, 1 => 30, 2 => 45 }, recovered[DT.topics[0]])
assert_equal({ 0 => 100 }, recovered[DT.topics[1]])

# Step 2: Write recovered offsets to the target group
Karafka::Admin::ConsumerGroups.seek(target_group, recovered)

# Step 3: Verify via Recovery that the target group has the same offsets
target_recovered = Karafka::Admin::Recovery.read_committed_offsets(
  target_group,
  last_committed_at: Time.now - 60
)

assert_equal recovered[DT.topics[0]], target_recovered[DT.topics[0]]
assert_equal recovered[DT.topics[1]], target_recovered[DT.topics[1]]

# Step 4: Verify via standard Admin API
lags = Karafka::Admin.read_lags_with_offsets(
  { target_group => [DT.topics[0], DT.topics[1]] }
)

assert_equal 15, lags[target_group][DT.topics[0]][0][:offset]
assert_equal 30, lags[target_group][DT.topics[0]][1][:offset]
assert_equal 45, lags[target_group][DT.topics[0]][2][:offset]
assert_equal 100, lags[target_group][DT.topics[1]][0][:offset]
