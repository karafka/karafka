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

# Karafka should correctly assign and manage the current attributes in multiple threads

setup_karafka do |config|
  config.concurrency = 10
end

setup_active_job

require 'karafka/active_job/current_attributes'

draw_routes do
  active_job_topic DT.topic do
    config(partitions: 50)
  end
end

class CurrentA < ActiveSupport::CurrentAttributes
  attribute :a
end

class CurrentB < ActiveSupport::CurrentAttributes
  attribute :b
end

Karafka::ActiveJob::CurrentAttributes.persist(CurrentA)
Karafka::ActiveJob::CurrentAttributes.persist(CurrentB)

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    sleep(rand / 100)
    DT[0] << [value, CurrentA.a, CurrentB.b]
  end
end

1000.times do |value|
  CurrentA.a = value
  CurrentB.b = value + 1
  Job.perform_later(value)
end

start_karafka_and_wait_until do
  DT[0].size >= 1000
end

DT[0].each do |result|
  assert_equal result[0], result[1]
  assert_equal result[0] + 1, result[2]
end
