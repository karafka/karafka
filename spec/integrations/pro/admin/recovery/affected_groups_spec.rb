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

# When scanning a __consumer_offsets partition for affected groups, we should discover all consumer
# groups that have committed offsets on that partition.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 2)
  end
end

GROUP1 = SecureRandom.uuid
GROUP2 = SecureRandom.uuid

# Commit offsets for both groups
Karafka::Admin::ConsumerGroups.seek(GROUP1, { DT.topics[0] => { 0 => 10 } })
Karafka::Admin::ConsumerGroups.seek(GROUP2, { DT.topics[0] => { 0 => 20 } })

sleep(2)

# Find which partition each group maps to
partition1 = Karafka::Admin::Recovery.offsets_partition_for(GROUP1)
partition2 = Karafka::Admin::Recovery.offsets_partition_for(GROUP2)

# Scan the partition for GROUP1 - it should at least contain GROUP1
result1 = Karafka::Admin::Recovery.affected_groups(partition1, last_committed_at: Time.now - 60)
assert result1.include?(GROUP1), "Expected to find #{GROUP1} on partition #{partition1}"

# If both groups happen to be on the same partition, both should appear
if partition1 == partition2
  assert result1.include?(GROUP2), "Expected to find #{GROUP2} on same partition"
else
  result2 = Karafka::Admin::Recovery.affected_groups(partition2, last_committed_at: Time.now - 60)
  assert result2.include?(GROUP2), "Expected to find #{GROUP2} on partition #{partition2}"
end

# Result should be sorted
assert_equal result1, result1.sort
