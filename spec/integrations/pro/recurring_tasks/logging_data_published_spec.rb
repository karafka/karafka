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

# When tasks are triggered, by default it should publish events to the logs topic
# This spec will hang if logs are not published

TASK_IDS = %w[a b c].freeze

setup_karafka

class CountConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:messages] << message.payload
    end
  end
end

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end

  topic Karafka::App.config.recurring_tasks.topics.logs.name do
    consumer CountConsumer
    deserializer Karafka::App.config.recurring_tasks.deserializer
  end
end

Karafka::Pro::RecurringTasks.define("1.0.0") do
  schedule(id: "a", cron: "0 12 31 12 *", enabled: false) do
    DT[:a] = true
  end

  schedule(id: "b", cron: "0 12 31 12 *", enabled: false) do
    DT[:b] = true
  end

  schedule(id: "c", cron: "0 12 31 12 *", previous_time: Time.now - 120_000) do
    DT[:c] = true
  end
end

start_karafka_and_wait_until do
  unless @dispatched
    Karafka::Pro::RecurringTasks.trigger("*")
    @dispatched = true
  end

  DT[:messages].count >= 3
end

DT[:messages].each_with_index do |payload, i|
  assert_equal payload[:schema_version], "1.0"
  assert_equal payload[:schedule_version], "1.0.0"
  assert_equal payload[:type], "log"
  assert payload[:dispatched_at].is_a?(Float)

  task = payload[:task]

  # Assertions for the task
  assert_equal task[:id], TASK_IDS[i]
  assert task[:time_taken].is_a?(Float)
  assert_equal task[:result], "success"
end
