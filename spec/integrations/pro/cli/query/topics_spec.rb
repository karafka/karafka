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

# karafka query topics should print matching topics as JSON and paginate them

setup_karafka

draw_topics do
  3.times do |i|
    topic DT.topics[i] do
      partitions i + 1
    end
  end
end

pattern = "^(#{DT.topics[0..2].join("|")})$"

ARGV.replace(["query", "topics", "--pattern", pattern, "--per_page", "2"])

output = StringIO.new
$stdout = output
Karafka::Cli.start
$stdout = STDOUT

first = JSON.parse(output.string)

ARGV.replace(["query", "topics", "--pattern", pattern, "--per_page", "2", "--page", "2"])

output = StringIO.new
$stdout = output
Karafka::Cli.start
$stdout = STDOUT

second = JSON.parse(output.string)

topics = (first["data"] + second["data"]).to_h { |topic| [topic["topic"], topic["partition_count"]] }

assert_equal 2, first["data"].size
assert_equal true, first["meta"]["has_more"]
assert_equal false, second["meta"]["has_more"]
assert_equal({ DT.topics[0] => 1, DT.topics[1] => 2, DT.topics[2] => 3 }, topics)
