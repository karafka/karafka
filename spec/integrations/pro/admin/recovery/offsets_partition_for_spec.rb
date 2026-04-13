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

# offsets_partition_for should return a valid partition number for the __consumer_offsets topic,
# be deterministic for the same input, and produce different results for different inputs.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

# Get the real __consumer_offsets partition count from cluster metadata.
# On CI the internal topic may not be immediately visible after cluster start, so we retry.
offsets_topic_info = nil

10.times do
  offsets_topic_info = Karafka::Admin.cluster_info.topics.find do |t|
    t[:topic_name] == "__consumer_offsets"
  end

  break if offsets_topic_info

  sleep(1)
end

assert offsets_topic_info, "__consumer_offsets topic not found in cluster metadata"

partition_count = offsets_topic_info[:partition_count]

# Should return a value within the valid partition range
result = Karafka::Admin::Recovery.offsets_partition_for("test-group")
assert result >= 0, "Partition should be >= 0"
assert result < partition_count, "Partition should be < #{partition_count}"

# Should be deterministic
first_call = Karafka::Admin::Recovery.offsets_partition_for("my-consumer-group")
second_call = Karafka::Admin::Recovery.offsets_partition_for("my-consumer-group")
assert_equal first_call, second_call

# Different group names should (generally) produce different partitions
partitions = %w[
  group-alpha group-beta group-gamma group-delta group-epsilon
  group-zeta group-eta group-theta group-iota group-kappa
].map { |g| Karafka::Admin::Recovery.offsets_partition_for(g) }

unique_count = partitions.uniq.size
assert unique_count > 1, "Expected different groups to map to different partitions, got all #{partitions.first}"
