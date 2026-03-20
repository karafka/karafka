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

# End-to-end blast radius assessment workflow on a multi-broker cluster:
# 1. Pick a broker via coordinator_for (known to work)
# 2. Find which __consumer_offsets partitions it leads (affected_partitions)
# 3. Discover which consumer groups live on those partitions (affected_groups)
# 4. Verify those groups are indeed coordinated by that broker (coordinator_for)

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 2)
  end
end

# Create several consumer groups with committed offsets
groups = Array.new(10) { SecureRandom.uuid }

groups.each do |group|
  Karafka::Admin::ConsumerGroups.seek(group, { DT.topics[0] => { 0 => 5 } })
end

sleep(2)

# Pick a broker by checking which broker coordinates one of our groups
coord = Karafka::Admin::Recovery.coordinator_for(groups.first)
target_broker = coord[:broker_id]

# Step 1: Find partitions led by this broker
partitions = Karafka::Admin::Recovery.affected_partitions(target_broker)
assert !partitions.empty?, "Expected partitions for broker #{target_broker}"

# Step 2: Discover groups on those partitions
discovered_groups = partitions.flat_map do |p|
  Karafka::Admin::Recovery.affected_groups(p, lookback_ms: 60 * 1_000)
end.uniq

# Step 3: Verify discovered groups are coordinated by the target broker
discovered_groups.each do |group|
  # Only check groups we created (others may exist from other tests)
  next unless groups.include?(group)

  coord_check = Karafka::Admin::Recovery.coordinator_for(group)
  assert_equal target_broker, coord_check[:broker_id],
    "Group #{group} should be coordinated by broker #{target_broker}, got #{coord_check[:broker_id]}"
end

# At least some of our groups should have been discovered
our_discovered = discovered_groups.select { |g| groups.include?(g) }
assert !our_discovered.empty?,
  "Expected to discover at least one of our test groups on broker #{target_broker}"
