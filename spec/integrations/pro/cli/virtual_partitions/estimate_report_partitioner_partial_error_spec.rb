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

# When the partitioner raises in some batches only, karafka vps estimate-report should name the
# partitioner as the cause and not blame key skew or suggest the :balanced distribution

setup_karafka

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

DT.uuids(100).each do |key|
  produce(DT.topic, key, key: key)
end

target_file = File.join(Dir.mktmpdir, "report.json")

Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator
  .new(
    concurrency: 5,
    batch_size: 10,
    partitioner: ->(message) { (message.offset < 90) ? raise("boom") : message.raw_key }
  )
  .call(DT.topic, target_file: target_file)

ARGV.replace(["vps", "estimate-report", target_file])

report = capture_stdout { Karafka::Cli.start }

assert report.include?("collapsed: 9")
assert report.include?("verdict: not_recommended")
assert report.include?("The partitioner raised an error in 9 of 10 batches")
assert report.include?("Fix the partitioner and run the estimate again.")
assert !report.include?("a few keys hold most of the messages")
assert !report.include?(":balanced")
