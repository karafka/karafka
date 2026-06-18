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

# With the :exact offset-metadata strategy and Virtual Partitions, an out-of-order mark where the
# batch-minimum VP group is still unmarked while a higher group marks used to raise a KeyError
# (F05): the materialized real offset falls back to (batch_min - 1) - an offset that was never
# registered - and `markable` did a strict `fetch` on it.
#
# Reproduced end-to-end: the first batch (offsets 0..99) is fully marked so the partition commits
# and the SECOND batch starts at offset 100 (a batch not starting at 0, required to make
# (min - 1) non-negative). In that batch the VP holding the minimum (offset 100) marks LAST, so
# while it is unmarked the higher VPs' marks trigger `markable`. On master this raises KeyError;
# with the fix it falls back to the current metadata and no error occurs.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 100
  config.concurrency = 10
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error].class.to_s
end

class Consumer < Karafka::BaseConsumer
  def consume
    first = messages.first.offset

    # First batch (0..99): no delay - mark everything so the real offset reaches 99 and commits,
    # so the next batch starts at offset 100 (a batch that does not start at 0, needed for F05).
    # Second batch (>= 100): stagger so the VP holding the batch minimum (offset 100) marks LAST.
    # While it is unmarked, the higher VPs' marks materialize a real offset of (100 - 1 = 99) and
    # call `markable` - the F05 path.
    sleep((110 - first) / 5.0) if first >= 100

    messages.each { |message| mark_as_consumed!(message, message.offset.to_s) }

    messages.each { |message| DT[:consumed] << message.offset }
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter(VpStabilizer)
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next },
      offset_metadata_strategy: :exact
    )
  end
end

produce_many(DT.topic, DT.uuids(200))

# Stop as soon as either an error surfaced (the bug) or the last offset was consumed (clean run),
# so a regression fails fast instead of looping on the collapse-and-retry the KeyError triggers.
start_karafka_and_wait_until do
  DT[:errors].any? || DT[:consumed].include?(199)
end

# The unmarked-batch-minimum state under :exact must not raise KeyError (F05).
assert(
  DT[:errors].none? { |klass| klass == "KeyError" },
  "KeyError(s) occurred: #{DT[:errors].tally}"
)
