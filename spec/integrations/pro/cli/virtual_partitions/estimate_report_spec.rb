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

# karafka vps estimate-report should display a report saved by the Virtual Partitions estimator
# and fail with one line and a non-zero exit code when the report file is missing or malformed.
# karafka vps help should list the available actions

setup_karafka

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

draw_routes do
  topic DT.topic do
    active false
  end
end

DT.uuids(20).each do |key|
  produce(DT.topic, key, partition: 1, key: key)
end

dir = Dir.mktmpdir
target_file = File.join(dir, "report.json")

Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator
  .new(batch_size: 10)
  .call(DT.topic, target_file: target_file)

def run_cli(*args)
  ARGV.replace(args)
  status = 0

  output = capture_stdout do
    Karafka::Cli.start
  rescue SystemExit => e
    status = e.status
  end

  [output, status]
end

report, status = run_cli("vps", "estimate-report", target_file)

assert_equal 0, status
assert report.include?("Virtual Partitions estimate for topic: #{DT.topic}")
assert report.include?("concurrency: #{Karafka::App.config.concurrency}")
assert report.include?("messages: 20")
assert report.include?("Caveats:")
assert !report.include?("\e[")

report, status = run_cli("virtual_partitions", "estimate-report", target_file)

assert_equal 0, status
assert report.include?("Virtual Partitions estimate for topic: #{DT.topic}")

missing = File.join(dir, "missing.json")
report, status = run_cli("vps", "estimate-report", missing)

assert_equal 1, status
assert_equal "Estimate report file not found: #{missing}\n", report

malformed = File.join(dir, "malformed.json")
File.write(
  malformed,
  JSON.generate(
    format_version: Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator::FORMAT_VERSION,
    partitions: [1, 2],
    settings: "x"
  )
)
report, status = run_cli("vps", "estimate-report", malformed)

assert_equal 1, status
assert_equal "Estimate report is not valid: #{malformed}\n", report

help, status = run_cli("vps", "help")

assert_equal 0, status
assert help.include?("estimate-report [path]")
