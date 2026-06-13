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

# Same real revocation scenario as the dlq_lrj_mom variant, but with a filter (throttling)
# configured so the strategy resolves to the ftr_lrj_mom flavor - a separate strategy file that
# carries its own copy of the `return resume if revoked?` guard and must be protected against
# regressing independently.
#
# Two partitions each carry one failing job, both run concurrently as LRJ, and a second consumer
# joins the same group and keeps polling so it permanently holds the partition rebalanced away
# from Karafka. Both failed jobs then reach their after-consume DLQ flow - one still owned, one
# revoked. Karafka must never dispatch a DLQ message for the partition it no longer owns.

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

draw_routes do
  active_job_topic DT.topic do
    config(partitions: 2)
    dead_letter_queue topic: DT.topics[1], max_retries: 0
    long_running_job true
    # mom is enabled automatically
    # A filter (throttling) selects the ftr_lrj_mom strategy; the limit is high enough not to
    # actually throttle the two failing messages
    throttling(limit: 1_000, interval: 1_000)
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

    true
  else
    false
  end
end

DT[:stop_holder] = true
holder_thread&.join
holder&.close

# The rebalance must actually have moved a partition to the second consumer, otherwise there was
# no revocation to test
assert held_partitions.size >= 1, "second consumer got no partition - no revocation happened"

# Karafka must not dispatch a DLQ message for any partition it no longer owns. With the guard the
# revoked partition stays silent; without it the revoked owner dispatches too.
leaked = DT[:dispatched] & held_partitions

assert(
  leaked.empty?,
  "DLQ dispatch happened on revoked partition(s) #{leaked} (dispatched: #{DT[:dispatched]}, " \
  "held by new owner: #{held_partitions})"
)
