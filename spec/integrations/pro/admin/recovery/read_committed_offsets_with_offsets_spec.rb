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

# When a consumer group has committed offsets and we read them via Recovery, we should get back the
# correct offsets per topic and partition.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 2)
  end

  topic DT.topics[1] do
    active false
    config(partitions: 1)
  end
end

GROUP_ID = SecureRandom.uuid

# Produce some messages so topics have data
produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topics[0], Array.new(10) { rand.to_s }, partition: 1)
produce_many(DT.topics[1], Array.new(10) { rand.to_s })

# Commit offsets for the consumer group via the normal Admin API
Karafka::Admin.seek_consumer_group(
  GROUP_ID,
  {
    DT.topics[0] => { 0 => 5, 1 => 8 },
    DT.topics[1] => { 0 => 3 }
  }
)

# Small sleep to ensure offsets are committed and visible in __consumer_offsets
sleep(2)

# Now recover them via the Recovery API
committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert !committed.empty?, "Expected to find committed offsets"

assert_equal 5, committed[DT.topics[0]][0]
assert_equal 8, committed[DT.topics[0]][1]
assert_equal 3, committed[DT.topics[1]][0]
