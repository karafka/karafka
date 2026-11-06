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

# The Virtual Partitions estimator should sample all partitions of a topic and estimate them
# without printing anything

setup_karafka

draw_topics do
  topic DT.topics[0] do
    partitions 2
  end
end

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

produce_many(DT.topics[0], Array.new(30) { |i| i.to_s }, partition: 0, key: "same")

DT.uuids(20).each do |key|
  produce(DT.topics[0], key, partition: 1, key: key)
end

estimator = Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator.new(
  batch_size: 10
)

result = estimator.call(DT.topics[0])

assert_equal DT.topics[0], result[:topic_name]
assert_equal [0, 1], result[:partitions].keys
assert_equal 30, result[:partitions][0][:messages]
assert_equal 3, result[:partitions][0][:batches]
assert_equal 3, result[:partitions][0][:single_vp_batches]
assert_equal 20, result[:partitions][1][:messages]
assert_equal 2, result[:partitions][1][:batches]
assert_equal 10.0, result[:partitions][1][:avg_unique_keys]
assert_equal 50, result[:summary][:messages]
assert_equal 5, result[:summary][:batches]
assert result.frozen?

report = Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator::Presenter
  .new(result)
  .to_s

assert report.include?("Virtual Partitions estimate for topic: #{DT.topics[0]}")

result = estimator.call(DT.topics[0], partitions: [1])

assert_equal [1], result[:partitions].keys
