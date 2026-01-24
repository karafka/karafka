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

# We should be able to mix partition delegation via `:key` with virtual partitions to achieve
# concurrent Active Job work execution.

setup_karafka do |config|
  config.concurrency = 10
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    virtual_partitions(
      partitioner: ->(job) { job.key }
    )
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync,
    partitioner: ->(job) { job.arguments.first[0] },
    partition_key_type: :key
  )

  def perform(value1)
    sleep(0.001 + (rand(5) / 1_000.0))
    DT[0] << value1
  end
end

order_without_vp = []

100.times do
  2.times do |iteration|
    order_without_vp << iteration.to_s
    Job.perform_later(iteration.to_s)
  end
end

start_karafka_and_wait_until do
  DT[0].size >= 200
end

assert_equal DT[0].size, order_without_vp.size

# Without virtual partitions we should get a consistent order, but with them and concurrent
# processing, it should not be like that
assert DT[0] != order_without_vp
