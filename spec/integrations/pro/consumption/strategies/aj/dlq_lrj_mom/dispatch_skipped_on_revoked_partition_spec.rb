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

# Long-running ActiveJob jobs run concurrently with partition revocation. When a failed LRJ batch
# reaches its after-consume DLQ flow after the partition was already revoked, it must not dispatch
# to the DLQ: the new owner will reprocess and dispatch. Without the guard the revoked owner also
# dispatches, producing a duplicate DLQ entry on a partition it no longer owns.
#
# This uses a REAL revocation (no stubbing of `#revoked?`): two partitions each carry one failing
# job, both run concurrently as LRJ, and a second consumer joins the same group and keeps polling
# so it permanently holds the partition rebalanced away from Karafka. Both failed jobs then reach
# their after-consume DLQ flow - one still owned, one revoked. The property we assert is precise
# and immune to the retained partition reprocessing under the rebalance: Karafka must never
# dispatch a DLQ message for a partition it no longer owns (the one the second consumer holds).

setup_active_job

setup_karafka(allow_errors: true) do |config|
  # Both partitions' jobs must run at the same time so both are in-flight LRJ when the rebalance
  # revokes one of them
  config.concurrency = 2
end

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].partition
end

class Job < ActiveJob::Base
  queue_as DT.topic

  # Route each job to the partition passed as its argument so we deterministically place one
  # failing job on each of the two partitions
  karafka_options(
    dispatch_method: :produce_sync,
    partitioner: ->(job) { job.arguments.first },
    partition_key_type: :partition
  )

  def perform(partition)
    DT[:started] << partition

    # Hold the long-running job open until the test has forced the rebalance, so the after-consume
    # DLQ flow runs after one of the two partitions has been revoked
    sleep(0.5) while DT[:rebalanced].empty?

    raise(StandardError, "poison")
  end
end

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

draw_routes do
  active_job_topic DT.topic do
    dead_letter_queue topic: DT.topics[1], max_retries: 0
    long_running_job true
    # mom is enabled automatically
  end

  topic DT.topics[1] do
    active(false)
  end
end

Job.perform_later(0)
Job.perform_later(1)

# Partitions held by the second consumer (i.e. revoked from Karafka). Captured inside the poll
# thread because an rdkafka consumer must only be touched from one thread.
held_partitions = []
held_snapshot = []
holder = nil
holder_thread = nil

start_karafka_and_wait_until do
  # Wait until both partitions are actively being processed (both LRJ jobs in-flight and blocked)
  if DT[:started].uniq.size >= 2 && DT[:rebalanced].empty?
    # Join a second consumer to the same group and keep it polling so it permanently holds the
    # partition it is assigned - that partition is revoked from Karafka and never reclaimed
    holder = setup_rdkafka_consumer
    holder.subscribe(DT.topic)
    holder_thread = Thread.new do
      until DT.key?(:stop_holder)
        holder.poll(1_000)
        current = holder.assignment.to_h.values.flatten.map(&:partition)
        held_partitions = current unless current.empty?
      end
    end

    # Give the rebalance time to settle so one partition is genuinely revoked from Karafka
    sleep(10)

    # Release the blocked jobs - both now run their after-consume DLQ flow, one owned, one revoked
    DT[:rebalanced] << true

    # Give both after-consume flows time to run before asserting
    sleep(8)

    # Freeze the holder's assignment while Karafka is still running. Returning true below stops
    # Karafka, whose shutdown rebalance hands its still-owned partition to the holder - capturing
    # that post-shutdown state would wrongly flag a partition that was dispatched while owned.
    held_snapshot = held_partitions.dup
    DT[:stop_holder] = true

    true
  else
    false
  end
end

holder_thread&.join
holder&.close

# The rebalance must actually have moved a partition to the second consumer, otherwise there was
# no revocation to test
assert held_snapshot.size >= 1, "second consumer got no partition - no revocation happened"

# Karafka must not dispatch a DLQ message for any partition it no longer owns. With the guard the
# revoked partition stays silent; without it the revoked owner dispatches too.
leaked = DT[:dispatched] & held_snapshot

assert(
  leaked.empty?,
  "DLQ dispatch happened on revoked partition(s) #{leaked} (dispatched: #{DT[:dispatched]}, " \
  "held by new owner: #{held_snapshot})"
)
