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

# Karafka::Pro::Admin::DeadLetterQueues.copy should copy only the requested partitions and offset
# range, keeping keys and headers and incrementing an existing replay count header.

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 2, 1)
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.producer.produce_many_sync(
  Array.new(10) do |i|
    {
      topic: DT.topics[0],
      partition: 1,
      payload: i.to_s,
      key: "key#{i}",
      headers: { "user" => "value", "replay_count" => "1" }
    }
  end
)

Karafka.producer.produce_sync(topic: DT.topics[0], partition: 0, payload: "other")

copied = Karafka::Pro::Admin::DeadLetterQueues.copy(
  DT.topics[0],
  target_topic_name: DT.topics[1],
  partitions: [1],
  start_offset: 3,
  end_offset: 6
)

assert_equal 3, copied

replayed = Karafka::Admin.read_topic(DT.topics[1], 0, 10, 0)

assert_equal %w[3 4 5], replayed.map(&:raw_payload)
assert_equal %w[key3 key4 key5], replayed.map(&:raw_key)
assert_equal [{ "user" => "value", "replay_count" => "2" }], replayed.map(&:raw_headers).uniq
