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

# Parallel consumer should also work with ActiveJob, though it will be a bit nondeterministic
# unless we use headers data to balance work.

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 50
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    # We do not publish any details with this job, thus we do a random work distribution
    virtual_partitions(
      partitioner: ->(_) { (0..4).to_a.sample }
    )
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    sleep(0.001)
    DT[0] << value
    DT[:threads_ids] << Thread.current.object_id
  end
end

values = (1..200).to_a
values.each { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 200
end

assert_equal 5, DT[:threads_ids].uniq.size
assert_equal values, DT[0].sort
assert_equal DT[0], DT[0].uniq
