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

# When a custom DLQ strategy requests a dispatch on the first failure of a virtually partitioned
# batch (instant dispatch of non-retryable errors), the decision must not be taken on the
# parallel (non-collapsed) run. There the deciding consumer sees only its own virtual partition
# subset: it would DLQ an arbitrary message from that subset and the dispatch marking would
# commit offsets of messages other virtual partitions never processed (silent data loss).
#
# The dispatch must instead happen after a collapsed retry, where the flow is linear and
# deterministic: only the genuinely poisoned message lands in the DLQ and everything else is
# processed.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 3
end

class AlwaysDispatchStrategy
  def call(_errors_tracker, _attempt)
    :dispatch
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    if collapsed?
      messages.each do |message|
        raise StandardError, "poison" if message.raw_payload == "2"

        DT[:processed] << message.raw_payload
        mark_as_consumed(message)
      end
    elsif messages.map(&:raw_payload).include?("2")
      # The virtual partition holding the poisoned (low) offsets fails before processing
      # anything from its subset
      raise StandardError, "poison"
    else
      # The other virtual partition processes its (high) offsets and finishes last, so it is
      # the one making the collective after-consume decision
      sleep(1)

      messages.each { |message| DT[:processed] << message.raw_payload }
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      strategy: AlwaysDispatchStrategy.new
    )
    virtual_partitions(
      partitioner: ->(msg) { (msg.raw_payload.to_i < 5) ? 0 : 1 },
      reducer: ->(key) { key }
    )
  end

  topic DT.topics[1] do
    active(false)
  end
end

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

produce_many(DT.topics[0], (0..9).map(&:to_s))

start_karafka_and_wait_until do
  if DT.key?(:dispatched)
    # Give the post-dispatch batches a moment to be processed before we stop
    sleep(7)

    true
  else
    false
  end
end

assert_equal(
  ["2"],
  DT[:dispatched].uniq,
  "an arbitrary message from the deciding virtual partition subset was dispatched to the DLQ"
)

assert_equal(
  %w[0 1 3 4 5 6 7 8 9],
  DT[:processed].uniq.sort,
  "messages of a failing virtual partition were committed past without processing (data loss)"
)
