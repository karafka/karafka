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

# Same older-marking regression as the OSS spec, but exercising the Pro default strategy (which
# carries its own copy of the guard). Marking an offset older than one already marked must be
# ignored - we only move forward. Before the fix the guard ignored only the exact last marked
# offset, so marking an older message rewound `coordinator.seek_offset`; a subsequent error then
# paused and seeked back to that offset and reprocessed everything in between - duplicates.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    # Only on the first batch: mark forward, then mark an older offset, then raise so the
    # error-driven retry pauses and seeks to coordinator.seek_offset
    return unless DT[:marked].empty?
    return if messages.size < 2

    DT[:marked] << true

    mark_as_consumed!(messages.last)
    mark_as_consumed!(messages.first)

    raise(StandardError, "trigger pause and seek")
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errored_at] = Time.now.to_f if event[:type] == "consumer.consume.error"
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT.key?(:errored_at) && (Time.now.to_f - DT[:errored_at]) > 10
end

assert DT[:marked].size >= 1, "the mark-older-then-raise scenario did not run"

# The older marking must be ignored, so the error's seek does not rewind and nothing is reprocessed
assert_equal DT[:offsets].uniq.size, DT[:offsets].size, DT[:offsets]
