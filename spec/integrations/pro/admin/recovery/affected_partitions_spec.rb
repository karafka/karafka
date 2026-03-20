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

# When querying affected partitions for a broker, we should get back all __consumer_offsets
# partitions led by that broker.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

metadata = Karafka::Admin.cluster_info
first_broker = metadata.brokers.first
broker_id = first_broker.is_a?(Hash) ? (first_broker[:broker_id] || first_broker[:node_id]) : first_broker.node_id

result = Karafka::Admin::Recovery.affected_partitions(broker_id)

# Should be a sorted array
assert result.is_a?(Array), "Expected Array, got #{result.class}"
assert_equal result, result.sort

# In a single-broker dev cluster, this broker leads all 50 partitions. In multi-broker clusters,
# it leads some subset.
assert !result.empty?, "Expected at least one partition led by broker #{broker_id}"

# All returned partition numbers should be valid
offsets_topic = metadata.topics.find { |t| t[:topic_name] == "__consumer_offsets" }
partition_count = offsets_topic[:partition_count]

result.each do |p|
  assert p >= 0 && p < partition_count,
    "Partition #{p} out of range (0...#{partition_count})"
end

# Non-existent broker should return empty array
empty_result = Karafka::Admin::Recovery.affected_partitions(99999)
assert_equal [], empty_result
