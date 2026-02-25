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

# When a job is marked as lrj, it should keep running longer than max poll interval and all
# should be good

setup_karafka do |config|
  # We set it here that way not too wait too long on stuff
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    long_running_job true
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform
    # Ensure we exceed max poll interval, if that happens and this would not work async we would
    # be kicked out of the group
    sleep(15)
    DT[0] << true
  end
end

Job.perform_later

start_karafka_and_wait_until do
  if DT.key?(0)
    sleep(15)
    true
  end
end

assert_equal 1, DT[0].size, "Given job should be executed only once"
