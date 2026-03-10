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

# Karafka should be stuck because we end up in a loop processing and failing

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

setup_active_job

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    raise StandardError if value == 1

    DT[0] << value
  end
end

draw_routes do
  active_job_topic DT.topic do
    # mom is enabled automatically
    throttling(limit: 10, interval: 1_000)
  end
end

10.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[:errors].size >= 10
end

assert_equal [0], DT[0].uniq
