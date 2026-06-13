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

# When marking as consumed out of order from a virtual partition while the virtual partition
# holding the lowest partition offset (0) has not marked yet, there is no real offset to commit
# yet. This is not a failure: `#mark_as_consumed` must still return true as long as the
# assignment is owned. Prior to the fix it returned the raw `#revoked?` result (false on a
# healthy assignment), falsely signaling a lost partition at the very start of a partition.

setup_karafka do |config|
  config.concurrency = 3
end

class Consumer < Karafka::BaseConsumer
  def consume
    offsets = messages.map(&:offset)
    DT[:groups] << offsets

    # Only the virtual partition group with offset 1 marks. The group holding offset 0 never
    # marks, so the lowest registered partition offset stays virtually unmarked
    return unless offsets.include?(1)
    return if DT.key?(:result)

    # Make sure the group containing partition offset 0 was scheduled (its offsets are
    # registered in the virtual offset manager before its work is queued), so the lowest
    # registered offset is 0 when we mark
    100.times do
      break if DT[:groups].any? { |group| group.include?(0) }

      sleep(0.1)
    end

    DT[:result] = mark_as_consumed(messages.first)
    DT[:revoked] = revoked?
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload.to_i % 2 },
      reducer: ->(key) { key }
    )
  end
end

produce_many(DT.topic, (0..9).map(&:to_s))

start_karafka_and_wait_until do
  DT.key?(:result)
end

assert_equal(
  false,
  DT[:revoked],
  "test setup expectation broken: assignment should be owned when marking"
)

assert_equal(
  true,
  DT[:result],
  "mark_as_consumed falsely signaled a lost partition (false) on an owned assignment"
)
