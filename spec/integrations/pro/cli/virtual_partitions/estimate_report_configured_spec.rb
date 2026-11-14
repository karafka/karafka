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

# Estimator defaults and the report file set in the consumer_groups.virtual_partitions.estimator
# config should be used by the estimator and by karafka vps estimate-report run without a path

dir = Dir.mktmpdir
report_file = File.join(dir, "configured.json")

setup_karafka do |config|
  config.consumer_groups.virtual_partitions.estimator.report_file = report_file
  config.consumer_groups.virtual_partitions.estimator.sample_size = 5
  config.consumer_groups.virtual_partitions.estimator.distribution = :balanced
end

draw_topics do
  topic DT.topic do
    partitions 1
  end
end

draw_routes do
  topic DT.topic do
    active false
  end
end

DT.uuids(20).each do |key|
  produce(DT.topic, key, partition: 0, key: key)
end

result = Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator
  .new(batch_size: 10)
  .call(DT.topic, target_file: report_file)

assert_equal 5, result[:settings][:sample_size]
assert_equal :balanced, result[:settings][:distribution]
assert_equal 5, result[:summary][:messages]

ARGV.replace(%w[vps estimate-report])
status = 0

report = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  status = e.status
end

assert_equal 0, status
assert report.include?("Virtual Partitions estimate for topic: #{DT.topic}")
assert report.include?("distribution: balanced")
assert report.include?("sample_size: 5")
