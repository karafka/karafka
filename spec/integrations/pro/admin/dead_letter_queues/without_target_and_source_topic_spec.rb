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

# Karafka::Pro::Admin::DeadLetterQueues.copy without a target topic should raise for a message that
# has no source topic header (as the OSS DLQ dispatches them) and dispatch nothing.

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 1, 1)
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.producer.produce_many_sync(
  [
    { topic: DT.topics[0], payload: "0", headers: { "source_topic" => DT.topics[1] } },
    { topic: DT.topics[0], payload: "1" }
  ]
)

begin
  Karafka::Pro::Admin::DeadLetterQueues.copy(DT.topics[0])
rescue Karafka::Pro::Admin::DeadLetterQueues::Errors::SourceTopicMissingError => e
  DT[:error] = e.message
end

assert_equal "#{DT.topics[0]}/0/1", DT[:error]
assert_equal [0, 0], Karafka::Admin.read_watermark_offsets(DT.topics[1], 0)
