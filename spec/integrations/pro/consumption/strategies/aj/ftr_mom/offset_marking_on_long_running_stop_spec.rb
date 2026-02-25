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

# Karafka upon long running jobs shutdown in this scenario, should early stop but should not
# mark the non-processed messages as consumed.

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 100
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value

    # First message is often the only in the first batch thuse we skip it
    sleep(15) if value > 0
  end
end

draw_routes do
  active_job_topic DT.topic do
    throttling(limit: 100, interval: 2_000)
  end
end

3.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 2
end

assert_equal 2, fetch_next_offset
