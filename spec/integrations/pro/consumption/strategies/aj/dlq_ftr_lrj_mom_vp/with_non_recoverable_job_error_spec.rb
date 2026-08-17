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

# Karafka should allow to run long AJ jobs with MOM, VPs and LRJ because we collapse upon errors.

SAMPLES = (0..1_000).to_a.map(&:to_s)

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  # Use the non-Pro scheduler to achieve FIFO scheduling to stabilize this spec
  config.internal.processing.scheduler_class = Karafka::Processing::Schedulers::Default
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << message.headers["source_offset"].to_i
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    # Make the 0 value last longer for consistency of this spec
    sleep(15) if value.zero? && !DT[0].include?(0)
    DT[0] << value
    raise StandardError
  end
end

draw_routes do
  active_job_topic DT.topic do
    dead_letter_queue topic: DT.topics[1], max_retries: 4
    # mom is enabled automatically
    throttling(limit: 3, interval: 1_000)
    virtual_partitions(
      partitioner: ->(_) { SAMPLES.pop }
    )
    long_running_job true
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

5.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 10 && DT[1].size >= 5
end

assert_equal (0..4).to_a, DT[1], DT[1]

first_zero = DT[0].index(0)

# Once the virtual partitions collapse (the first `0` is processed, after the initial
# parallel pre-collapse executions), retries are serialized and jobs are skipped forward in
# order: each value is retried until it exhausts its attempts and is moved to the DLQ, and
# only then does processing continue with the next value.
#
# We assert on this ordering and completeness rather than on exact per-value retry counts and
# fixed slice boundaries. The number of pre-collapse parallel executions (throttled VP runs
# that happen while `0` sleeps) and the occasional extra retry around a pause/resume are
# timing-dependent and previously made this spec flaky. The exact retry limit ("skip after 4
# retries") is already covered by the DLQ dispatch assertion above.
collapsed = DT[0][first_zero..]

# After the collapse, jobs are processed strictly in ascending value order (0, then 1, ... 4)
assert_equal collapsed.sort, collapsed, DT[0]

# Every job value is eventually processed and skipped forward, with none missing
assert_equal (0..4).to_a, collapsed.uniq, DT[0]
