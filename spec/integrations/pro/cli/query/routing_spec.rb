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

# karafka query routing should print routed topics with consumers and their source location

setup_karafka

class QueryRoutingConsumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer QueryRoutingConsumer
  end
end

ARGV.replace(%w[query routing])

output = StringIO.new
$stdout = output
Karafka::Cli.start
$stdout = STDOUT

result = JSON.parse(output.string)
row = result["data"].first

assert_equal true, result["ok"]
assert_equal ["routing"], result["meta"]["sources"]
assert_equal DT.group, row["group_id"]
assert_equal "consumer", row["group_type"]
assert_equal DT.topic, row["topic"]
assert_equal "QueryRoutingConsumer", row["consumer"]
definition_line = File.readlines(__FILE__).index { |line| line.start_with?("class Query") } + 1

assert_equal definition_line, row["source_location"]["line"]
assert row["source_location"]["path"].end_with?("routing_spec.rb")
