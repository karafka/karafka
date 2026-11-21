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

# The Virtual Partitions estimator should score data by the speedup Virtual Partitions would
# give it. One hot key with a few stray keys uses many virtual partitions but is not sped up, so
# it should score below two equal keys and not get the maybe verdict, also at a concurrency of 2

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

200.times do |i|
  produce(DT.topics[0], i.to_s, partition: 0, key: (i % 100 < 96) ? "hot" : "stray-#{i}")
  produce(DT.topics[0], i.to_s, partition: 1, key: %w[a b][i % 2])
end

estimator = Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator.new(
  concurrency: 5,
  batch_size: 100
)

result = estimator.call(DT.topics[0])

hot_key = result[:partitions][0]
two_keys = result[:partitions][1]

assert_equal 1.0, hot_key[:avg_speedup]
assert_equal :not_recommended, hot_key[:verdict]
assert hot_key[:avg_active_vps] > two_keys[:avg_active_vps]
assert_equal 2.0, two_keys[:avg_speedup]
assert_equal :maybe, two_keys[:verdict]
assert two_keys[:score] > hot_key[:score]

result = Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator.new(
  concurrency: 2,
  batch_size: 100
).call(DT.topics[0])

assert_equal :not_recommended, result[:partitions][0][:verdict]
assert_equal :recommended, result[:partitions][1][:verdict]
