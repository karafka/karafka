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

# karafka query topic should print a not_found error as JSON, exit with a distinct code and not
# create the topic it was asked about

setup_karafka

ARGV.replace(["query", "topic", "--topic_name", DT.topic])

output = StringIO.new
status = nil
$stdout = output

begin
  Karafka::Cli.start
rescue SystemExit => e
  status = e.status
end

$stdout = STDOUT

result = JSON.parse(output.string)

assert_equal 3, status
assert_equal false, result["ok"]
assert_equal "not_found", result["error"]
assert_equal DT.topic, result["details"]["value"]
assert_equal false, Karafka::Admin.cluster_info.topics.any? { |t| t[:topic_name] == DT.topic }
