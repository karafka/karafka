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

# When we have an vp AJ jobs in few batches, upon shutdown, not finished work should not be
# committed, but the previous offset should. Only fully finished AJ VP batches should be considered
# finished.

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 2
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    virtual_partitions(
      partitioner: ->(_) { (0..4).to_a.sample }
    )
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    sleep(1)
    DT[0] << value
  end
end

values = (1..200).to_a
values.each { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 10
end

sleep(1)

# Intermediate jobs should be processed
assert fetch_next_offset > 0
