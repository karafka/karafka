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

# In a multi-broker cluster, different consumer groups should map to different coordinators. This
# verifies that coordinator_for returns valid broker info and that groups are distributed across
# the cluster.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

metadata = Karafka::Admin.cluster_info

broker_ids = metadata.brokers.map do |b|
  b.is_a?(Hash) ? (b[:broker_id] || b[:node_id]) : b.node_id
end.sort

# Generate several groups and check their coordinators
groups = Array.new(20) { SecureRandom.uuid }
coordinators = {}

groups.each do |group|
  result = Karafka::Admin::Recovery.coordinator_for(group)

  # Each result should have valid structure
  assert result.key?(:partition), "Missing :partition for #{group}"
  assert result.key?(:broker_id), "Missing :broker_id for #{group}"
  assert result.key?(:broker_host), "Missing :broker_host for #{group}"

  # broker_id should exist in the cluster
  assert broker_ids.include?(result[:broker_id]),
    "Broker #{result[:broker_id]} not in cluster #{broker_ids}"

  # broker_host should have host:port format
  assert result[:broker_host].match?(/\A.+:\d+\z/),
    "Expected host:port format, got #{result[:broker_host]}"

  coordinators[group] = result[:broker_id]
end

# With 20 random groups on a multi-broker cluster, we should see multiple coordinators
unique_coordinators = coordinators.values.uniq
assert unique_coordinators.size > 1,
  "Expected groups distributed across multiple brokers, got only broker(s): #{unique_coordinators}"
