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

# karafka query lags filters should return only the matching consumer groups and topics, and no
# rows (not the other consumer groups lags) when the filters match nothing

setup_karafka

draw_routes do
  consumer_group DT.groups[0] do
    topic DT.topics[0] do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  consumer_group DT.groups[1] do
    topic DT.topics[1] do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

produce_many(DT.topics[0], DT.uuids(3))
produce_many(DT.topics[1], DT.uuids(5))

Karafka::Admin.seek_consumer_group(DT.groups[0], { DT.topics[0] => { 0 => 1 } })
Karafka::Admin.seek_consumer_group(DT.groups[1], { DT.topics[1] => { 0 => 2 } })

def query(*args)
  ARGV.replace(["query", "lags", *args])
  output = Tempfile.create("query").tap { |file| file.sync = true }
  $stdout = output
  Karafka::Cli.start
  $stdout = STDOUT

  JSON.parse(File.read(output.path))
end

def summary(result)
  result["data"].map { |row| row.values_at("consumer_group_id", "topic", "lag_committed") }
end

assert_equal(
  [[DT.groups[0], DT.topics[0], 2], [DT.groups[1], DT.topics[1], 3]].sort,
  summary(query)
)

assert_equal(
  [[DT.groups[1], DT.topics[1], 3]],
  summary(query("--consumer_group_id", DT.groups[1]))
)

assert_equal(
  [[DT.groups[0], DT.topics[0], 2]],
  summary(query("--topic_name", DT.topics[0]))
)

assert_equal [], summary(query("--consumer_group_id", "#{DT.groups[0]}-unknown"))
assert_equal [], summary(query("--topic_name", "#{DT.topics[0]}-unknown"))

# An explicit consumer group and topic pair is read even when not routed together
assert_equal(
  [[DT.groups[0], DT.topics[1], -1]],
  summary(query("--consumer_group_id", DT.groups[0], "--topic_name", DT.topics[1]))
)
