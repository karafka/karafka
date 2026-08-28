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

# With a transactional DLQ dispatch and `mark_after_dispatch: false`, the in-memory seek_offset
# was advanced inside the dispatch transaction. If the transaction then aborts (e.g. a commit
# failure), the DLQ message is rolled back but the advanced seek_offset survives: the failure
# path pauses at the advanced offset, so the broken message is neither in the DLQ nor reprocessed
# and subsequent markings commit past it - silent loss.
#
# After an aborted dispatch transaction the broken message must be retried (the DLQ dispatch
# re-attempted), so it eventually lands in the DLQ instead of being dropped.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
end

# Fail the commit of the first DLQ dispatch transaction exactly once, after its body (the DLQ
# produce and the in-memory seek_offset advance) has run. Mirrors a broker-side transaction
# commit failure
module FailFirstDlqDispatchTransaction
  def transaction(*args, **kwargs, &block)
    super do
      result = block.call

      if DT.key?(:dlq_produced) && !DT.key?(:dlq_commit_failed)
        DT[:dlq_commit_failed] = true

        raise(StandardError, "simulated DLQ transaction commit failure")
      end

      result
    end
  end
end

WaterDrop::Producer.prepend(FailFirstDlqDispatchTransaction)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do
  DT[:dlq_produced] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise(StandardError, "poison") if message.raw_payload == "poison"

      DT[:processed] << message.raw_payload
      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 1,
      transactional: true,
      mark_after_dispatch: false
    )
  end

  topic DT.topics[1] do
    active(false)
  end
end

# offsets: ok-before=0, poison=1, ok-after-a=2, ok-after-b=3
produce_many(DT.topics[0], %w[ok-before poison ok-after-a ok-after-b])

start_karafka_and_wait_until do
  DT[:processed].include?("ok-after-b")
end

dlq_messages = Karafka::Admin.read_topic(DT.topics[1], 0, 10)

assert_equal(
  1,
  dlq_messages.size,
  "poison message lost: rolled back from the DLQ on the aborted transaction and skipped"
)

assert_equal "poison", dlq_messages.first.raw_payload
