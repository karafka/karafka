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

# Karafka should recover from errors when using AJ + LRJ + MoM + VP by collapsing VPs and retrying

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 100
  config.concurrency = 5
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
    raise StandardError if value == 0 && DT[0].count(&:zero?) < 3
  end
end

draw_routes do
  active_job_topic DT.topic do
    long_running_job true
    virtual_partitions(
      partitioner: ->(message) { message.offset % 10 },
      max_partitions: 10
    )
  end
end

10.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].count(&:zero?) >= 3
end

# Job 0 should have been retried at least 3 times before finally succeeding
assert DT[0].count(&:zero?) >= 3
# All jobs should have been processed
assert_equal (0..9).to_a, DT[0].uniq.sort
