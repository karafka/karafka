# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# When some AJ slow jobs fail permanently while others succeed with LRJ enabled,
# only the failing jobs should be dispatched to DLQ after max retries.

SAMPLES = (0..1_000).to_a.map(&:to_s)

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
  config.max_messages = 10
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
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
    sleep(15) if value.zero? && !DT[0].include?(0)
    DT[0] << value
    raise StandardError if value.zero?
  end
end

draw_routes do
  active_job_topic DT.topic do
    dead_letter_queue topic: DT.topics[1], max_retries: 2
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
  DT[0].size >= 5 && DT[1].size >= 1
end

# Job 0 should have been dispatched to DLQ
assert DT[1].include?(0), DT[1]
# All other jobs should have been processed
assert_equal (0..4).to_a, DT[0].uniq.sort
