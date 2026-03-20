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

# When a consumer group has committed offsets for only some partitions of a multi-partition topic,
# Recovery should return only the partitions that have committed offsets and not include others.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
    config(partitions: 4)
  end
end

GROUP_ID = SecureRandom.uuid

produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 1)
produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 2)
produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 3)

# Only commit offsets for partitions 1 and 3, skipping 0 and 2
Karafka::Admin.seek_consumer_group(
  GROUP_ID,
  { DT.topic => { 1 => 5, 3 => 8 } }
)

sleep(2)

committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  last_committed_at: Time.now - 60
)

assert !committed.empty?, "Expected to find committed offsets"

# Partitions that were committed should be present with correct values
assert_equal 5, committed[DT.topic][1]
assert_equal 8, committed[DT.topic][3]

# Partitions that were NOT committed should be absent
assert !committed[DT.topic].key?(0), "Partition 0 should not be present"
assert !committed[DT.topic].key?(2), "Partition 2 should not be present"
