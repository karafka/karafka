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

# karafka query topic should print partitions, watermarks and configs of a topic as JSON

setup_karafka

draw_topics do
  topic DT.topic do
    partitions 2
    config("retention.ms": 86_400_000)
  end
end

produce_many(DT.topic, DT.uuids(5), partition: 1)

ARGV.replace(["query", "topic", "--topic-name", DT.topic])

output = Tempfile.create("query").tap { |file| file.sync = true }
$stdout = output
Karafka::Cli.start
$stdout = STDOUT

result = JSON.parse(File.read(output.path))
data = result["data"]

assert_equal true, result["ok"]
assert_equal DT.topic, data["topic"]
assert_equal 2, data["partition_count"]
assert_equal [0, 1], data["partitions"].map { |partition| partition["partition"] }
assert_equal [0, 5], data["partitions"].map { |partition| partition["high_watermark"] }

retention = data["configs"].find { |config| config["name"] == "retention.ms" }

assert_equal "86400000", retention["value"]
assert_equal false, retention["default"]
