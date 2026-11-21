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

# A process-critical error (SystemExit via `exit`) raised in a collapsed virtual partitions run
# must never be dispatched to the DLQ, even when its retries are used up. The partition stays
# paused during the self-initiated shutdown, the failed batch is not committed and it is
# redelivered after the restart.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      if message.offset == 5 && !DT.key?(:second_run)
        # A regular error collapses the virtual partitions, so the critical one surfaces in the
        # collapsed run, where the DLQ flow would otherwise dispatch
        raise StandardError unless collapsed?

        DT[:failed_batch_first] = messages.first.offset

        exit(1)
      end

      DT[:consumed] << message.offset
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 1
    )
  end
end

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |_event|
  DT[:dispatched] << 1
end

produce_many(DT.topics[0], (0..9).map(&:to_s))

# The stop is initiated by the framework, the wait block only observes
start_karafka_and_wait_until(reset_status: true) do
  DT.key?(:failed_batch_first) && Karafka::App.done?
end

assert_equal [], DT[:dispatched]
assert_equal DT[:failed_batch_first], fetch_next_offset(DT.topics[0])

DT[:second_run] = true

start_karafka_and_wait_until do
  ((0..9).to_a - DT[:consumed].uniq).empty?
end

assert_equal (0..9).to_a, DT[:consumed].uniq.sort
assert_equal [], DT[:dispatched]
