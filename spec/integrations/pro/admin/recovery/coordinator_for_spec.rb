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

# When looking up the coordinator for a consumer group, we should get back valid broker information
# matching the real cluster.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

# Produce a message and commit an offset so the __consumer_offsets internal topic is guaranteed
# to exist in cluster metadata. On a fresh CI broker it may not exist until a consumer group
# has committed at least once.
produce(DT.topics[0], "warmup")

Karafka::Admin.seek_consumer_group(GROUP_ID, { DT.topics[0] => { 0 => 0 } })

# On a fresh CI broker the __consumer_offsets topic may take a while to appear in cluster
# metadata even after a commit. Retry the first Recovery call with exponential backoff for
# up to ~30 s before giving up with the original MetadataError.
result = nil
backoff = 1
total_waited = 0

loop do
  begin
    result = Karafka::Admin::Recovery.coordinator_for(GROUP_ID)
    break
  rescue Karafka::Pro::Admin::Recovery::Errors::MetadataError
    raise if total_waited >= 30

    sleep(backoff)
    total_waited += backoff
    backoff = [backoff * 2, 10].min
  end
end

# Should return the expected partition
expected_partition = Karafka::Admin::Recovery.offsets_partition_for(GROUP_ID)
assert_equal expected_partition, result[:partition]

# broker_id should be a non-negative integer
assert result[:broker_id] >= 0, "Expected non-negative broker_id, got #{result[:broker_id]}"

# broker_host should have host:port format
assert result[:broker_host].match?(/\A.+:\d+\z/),
  "Expected host:port format, got #{result[:broker_host]}"

# Verify the broker actually exists in cluster metadata
metadata = Karafka::Admin.cluster_info
broker_ids = metadata.brokers.map do |b|
  b.is_a?(Hash) ? (b[:broker_id] || b[:node_id]) : b.node_id
end

assert broker_ids.include?(result[:broker_id]),
  "Broker #{result[:broker_id]} not found in cluster"
