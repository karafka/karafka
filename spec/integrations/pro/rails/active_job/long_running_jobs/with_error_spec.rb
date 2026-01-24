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

# When we have an lrj job and it fails, it should use regular Karafka retry policies

setup_karafka(allow_errors: true)

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    long_running_job true
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform
    sleep 5

    if DT[0].empty?
      DT[0] << '1'
      raise StandardError
    else
      DT[0] << '2'
    end
  end
end

Job.perform_later

start_karafka_and_wait_until do
  DT[0].size >= 2
end

assert_equal '1', DT[0][0]
assert_equal '2', DT[0][1]
