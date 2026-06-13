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
# to the DLQ: the new owner will reprocess and dispatch. The non-AJ LRJ DLQ strategies guard this
# with `return resume if revoked?`; the AJ LRJ DLQ variants lacked the guard and dispatched on the
# lost partition, producing a DLQ entry that the new owner then duplicates.
#
# This covers the filtering (throttling) variant: a filter is configured so the strategy resolves
# to the ftr_lrj_mom flavor, and the revocation guard before the DLQ dispatch must still hold.

setup_active_job
setup_karafka(allow_errors: true)

# Simulate the partition being revoked from the moment the job fails, so the after-consume DLQ
# flow runs while we no longer own the partition
module SimulatedRevocation
  def revoked?
    DT.key?(:simulate_revoked) || super
  end
end

Karafka::BaseConsumer.prepend(SimulatedRevocation)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do
  DT[:dlq_dispatched] = true
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errored_at] = Time.now.to_f if event[:type] == "consumer.consume.error"
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:simulate_revoked] = true

    raise(StandardError, "poison")
  end
end

draw_routes do
  active_job_topic DT.topic do
    dead_letter_queue topic: DT.topics[1], max_retries: 0
    long_running_job true
    # mom is enabled automatically
    # A filter (throttling) selects the ftr_lrj_mom strategy; the limit is high enough not to
    # actually throttle the single failing message
    throttling(limit: 1_000, interval: 1_000)
  end

  topic DT.topics[1] do
    active(false)
  end
end

Job.perform_later

# Wait until the job has failed, then give the (now revoked) after-consume DLQ flow ample time to
# run before asserting whether it dispatched
start_karafka_and_wait_until do
  DT.key?(:errored_at) && (Time.now.to_f - DT[:errored_at]) > 8
end

assert(
  !DT.key?(:dlq_dispatched),
  "failed message dispatched to the DLQ while the partition was revoked"
)
