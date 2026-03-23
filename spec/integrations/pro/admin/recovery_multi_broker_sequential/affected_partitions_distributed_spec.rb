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

# In a multi-broker cluster, __consumer_offsets partitions should be distributed across brokers.
# affected_partitions should return different subsets for each broker, and together they should cover
# all partitions exactly once.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

# Produce some records and commit offsets so the __consumer_offsets topic is guaranteed to exist
# on all brokers before we try to query partition metadata
produce_many(DT.topics[0], Array.new(10) { rand.to_s })

Karafka::Admin.seek_consumer_group(
  SecureRandom.uuid,
  { DT.topics[0] => { 0 => 5 } }
)

metadata = Karafka::Admin.cluster_info

broker_ids = metadata.brokers.map do |b|
  b.is_a?(Hash) ? (b[:broker_id] || b[:node_id]) : b.node_id
end

# Collect partitions led by each broker.
# On fresh KRaft clusters __consumer_offsets may take time to appear in metadata
# (RF=3, 50 partitions), so retry the first call with a bounded timeout.
all_partitions = []
first_call = true

broker_ids.each do |bid|
  partitions = nil

  if first_call
    60.times do
      partitions = Karafka::Admin::Recovery.affected_partitions(bid)
      break
    rescue Karafka::Pro::Admin::Recovery::Errors::MetadataError
      sleep(1)
    end

    first_call = false
  else
    partitions = Karafka::Admin::Recovery.affected_partitions(bid)
  end

  assert partitions.is_a?(Array), "Expected Array for broker #{bid}"
  assert_equal partitions, partitions.sort, "Partitions should be sorted for broker #{bid}"
  all_partitions.concat(partitions)
end

# In a multi-broker cluster, partitions should be distributed across brokers
per_broker = broker_ids.map { |bid| Karafka::Admin::Recovery.affected_partitions(bid) }
non_empty = per_broker.reject(&:empty?)
assert non_empty.size > 1, "Expected partitions distributed across multiple brokers"

# Together, all brokers should cover every partition exactly once (contiguous range 0..N-1)
assert all_partitions.size.positive?, "Expected some __consumer_offsets partitions"
assert_equal (0...all_partitions.size).to_a, all_partitions.sort,
  "Expected contiguous partition range 0..#{all_partitions.size - 1}"
