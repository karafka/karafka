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

# When two different consumer groups have committed offsets for the same topic, Recovery should
# only return offsets for the requested group and not leak offsets from other groups.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
    config(partitions: 2)
  end
end

GROUP_A = SecureRandom.uuid
GROUP_B = SecureRandom.uuid

produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 0)
produce_many(DT.topic, Array.new(10) { rand.to_s }, partition: 1)

# Group A commits offset 5 on partition 0
Karafka::Admin.seek_consumer_group(GROUP_A, { DT.topic => { 0 => 5 } })

# Group B commits offset 9 on partition 1
Karafka::Admin.seek_consumer_group(GROUP_B, { DT.topic => { 1 => 9 } })

sleep(2)

# Read offsets for Group A only
committed_a = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_A,
  last_committed_at: Time.now - 60
)

assert_equal 5, committed_a[DT.topic][0]
assert !committed_a[DT.topic].key?(1), "Group A should not have partition 1 offsets"

# Read offsets for Group B only
committed_b = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_B,
  last_committed_at: Time.now - 60
)

assert_equal 9, committed_b[DT.topic][1]
assert !committed_b[DT.topic].key?(0), "Group B should not have partition 0 offsets"
