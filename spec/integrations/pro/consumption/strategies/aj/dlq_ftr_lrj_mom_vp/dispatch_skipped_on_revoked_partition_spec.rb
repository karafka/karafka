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

# Same real revocation scenario as the dlq_lrj_mom_vp variant, but with a filter (throttling) so
# the strategy resolves to the ftr_lrj_mom_vp flavor - a separate strategy file carrying its own
# copy of the `return resume if revoked?` guard. VPs decide DLQ dispatch on the collapsed retry,
# so each job fails once to trigger the collapse, then blocks on the collapsed re-run until the
# test has forced a real rebalance, making the dispatch decision happen while revoked.
#
# Two partitions each carry one failing job; a second consumer joins the same group and keeps
# polling so it permanently holds the partition rebalanced away from Karafka. Karafka must never
# dispatch a DLQ message for the partition it no longer owns.

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 2
end

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].partition
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync,
    partitioner: ->(job) { job.arguments.first },
    partition_key_type: :partition
  )

  def perform(partition)
    DT[:"perf_#{partition}"] << true

    # First attempt fails immediately to trigger the VP collapse. The collapsed re-run (where the
    # dispatch decision is actually made) blocks until the test has forced the revocation
    if DT[:"perf_#{partition}"].size >= 2
      DT[:collapsed] << partition
      sleep(0.5) while DT[:rebalanced].empty?
    end

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
    # VP + DLQ requires at least one retry; the collapsed retry is where dispatch is decided
    dead_letter_queue topic: DT.topics[1], max_retries: 1
    long_running_job true
    # mom is enabled automatically
    # A filter (throttling) selects the ftr_lrj_mom_vp strategy; the limit is high enough not to
    # actually throttle the two failing messages
    throttling(limit: 1_000, interval: 1_000)
    virtual_partitions(
      partitioner: ->(_) { rand.to_s }
    )
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
  # Wait until both partitions are on their collapsed re-run (blocked) before forcing the rebalance
  if DT[:collapsed].uniq.size >= 2 && DT[:rebalanced].empty?
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

    # Release the blocked collapsed jobs - both run their dispatch decision, one owned, one revoked
    DT[:rebalanced] << true

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

assert held_snapshot.size >= 1, "second consumer got no partition - no revocation happened"

# Karafka must not dispatch a DLQ message for any partition it no longer owns
leaked = DT[:dispatched] & held_snapshot

assert(
  leaked.empty?,
  "DLQ dispatch happened on revoked partition(s) #{leaked} (dispatched: #{DT[:dispatched]}, " \
  "held by new owner: #{held_snapshot})"
)
