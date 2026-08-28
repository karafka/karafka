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

# F34: `Pro::Iterator#each` reset `@stopped_partitions`/`@stopped` only after the `with_consumer`
# block, so a `break` out of the yielded block (a documented way to stop) skipped the reset. The
# accumulated EOF state then leaked into the next `#each`: `done?` was immediately true and the
# whole iteration was a silent no-op, dropping a fresh backlog.
#
# Reproduced by iterating to EOF, breaking, then reusing the SAME iterator. With `yield_nil` the
# drained (single-partition) iterator yields a nil once it reaches EOF - i.e. once
# `@stopped_partitions` is full - giving us a point to `break` on while the state is full. The
# second pass over the same iterator must still re-stream the whole backlog.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

MESSAGES = 10

produce_many(DT.topic, DT.uuids(MESSAGES))

# `yield_nil` so the drained partition yields a nil at EOF (when @stopped_partitions is full); a
# larger max_wait_time keeps poll from returning a premature timeout-nil before EOF is registered.
iterator = Karafka::Pro::Iterator.new(DT.topic, yield_nil: true, max_wait_time: 1_000)

# First pass: drain the whole backlog, then break on the post-EOF nil (so the break happens with
# @stopped_partitions full - the exact condition that made the next run a no-op).
first = []

iterator.each do |message, _iterator|
  if message.nil?
    # Only break once the whole backlog is drained, so this nil is the post-EOF retry nil and not
    # a premature poll timeout.
    break if first.size >= MESSAGES
  else
    first << message.offset
  end
end

# Second pass on the SAME iterator: it must re-stream the backlog from the beginning. Before the
# fix, the un-reset @stopped_partitions made `done?` immediately true and this yielded nothing.
second = []

iterator.each do |message, _iterator|
  next if message.nil?

  second << message.offset

  break if second.size >= MESSAGES
end

assert_equal((0...MESSAGES).to_a, first)
assert_equal((0...MESSAGES).to_a, second)
