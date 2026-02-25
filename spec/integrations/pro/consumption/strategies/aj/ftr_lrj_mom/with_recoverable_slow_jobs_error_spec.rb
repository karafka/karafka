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

# Karafka should recover from this error and move on. Throttling should not impact order or
# anything else.

setup_active_job

setup_karafka(allow_errors: true)

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
    sleep(value.to_f / 100)
    raise StandardError if DT[0].size < 5
  end
end

draw_routes do
  active_job_topic DT.topic do
    max_messages 20
    long_running_job true
    # mom is enabled automatically
    throttling(limit: 10, interval: 2_000)
  end
end

50.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].uniq.size >= 50
end

assert_equal DT[0], [0, 0, 0, 0, 0] + (1..49).to_a
