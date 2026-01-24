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

# Karafka should allow to define ActiveJob patterns via `#active_job_pattern` and those should
# be picked up and operable even when topics are created after the subscription starts

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
end

setup_active_job

draw_routes(create_topics: false) do
  active_job_pattern(/(#{DT.topics[0]}|#{DT.topics[1]})/)
end

class Job1 < ActiveJob::Base
  queue_as DT.topics[0]

  def perform
    DT[0] << true
  end
end

class Job2 < ActiveJob::Base
  queue_as DT.topics[1]

  def perform
    DT[1] << true
  end
end

start_karafka_and_wait_until do
  sleep(2)

  unless @sent
    Job1.perform_later
    Job2.perform_later
    @sent = true
  end

  DT.key?(0) && DT.key?(1)
end
