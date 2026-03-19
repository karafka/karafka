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

# When a consumer group has committed offset 0 for a partition, Recovery should return it
# correctly and not treat it as a missing/falsy value.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

produce_many(DT.topic, Array.new(10) { rand.to_s })

# Commit offset 0 explicitly
Karafka::Admin.seek_consumer_group(GROUP_ID, { DT.topic => { 0 => 0 } })

sleep(2)

committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  lookback_ms: 60 * 1_000
)

assert !committed.empty?, "Expected to find committed offsets"
assert committed[DT.topic].key?(0), "Partition 0 should be present"
assert_equal 0, committed[DT.topic][0]
