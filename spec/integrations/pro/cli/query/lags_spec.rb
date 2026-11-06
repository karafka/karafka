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

# karafka query lags should print committed offsets and lags of routed consumer groups as JSON

setup_karafka

draw_routes do
  topic DT.topic do
    consumer Class.new(Karafka::BaseConsumer)
  end
end

produce_many(DT.topic, DT.uuids(10))

Karafka::Admin.seek_consumer_group(DT.group, { DT.topic => { 0 => 4 } })

ARGV.replace(["query", "lags", "--topic_name", DT.topic, "--json"])

output = Tempfile.create("query").tap { |file| file.sync = true }
$stdout = output
Karafka::Cli.start
$stdout = STDOUT

result = JSON.parse(File.read(output.path))

assert_equal 1, result["schema_version"]
assert_equal true, result["ok"]
assert_equal ["broker"], result["meta"]["sources"]
assert_equal 1, result["meta"]["page"]
assert_equal false, result["meta"]["has_more"]

assert_equal(
  [
    {
      "consumer_group_id" => DT.group,
      "topic" => DT.topic,
      "partition" => 0,
      "offset_committed" => 4,
      "lag_committed" => 6
    }
  ],
  result["data"]
)
