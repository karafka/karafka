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

# Karafka Pro should automatically assign the tag of job class that is executed

setup_karafka
setup_active_job

draw_routes do
  active_job_topic DT.topic do
    dead_letter_queue topic: DT.topics[1], max_retries: 4
  end
end

Karafka.monitor.subscribe("consumer.consumed") do |event|
  DT[:tags] << event[:caller].tags.to_a.first
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[0] << true
  end
end

Job.perform_later

start_karafka_and_wait_until do
  DT.key?(0)
end

assert_equal [Job.to_s], DT[:tags]
