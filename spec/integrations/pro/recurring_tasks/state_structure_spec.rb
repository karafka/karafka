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

# The state structure should comply with our expectations

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.0.1') do
  schedule(id: 'a', cron: '0 12 31 12 *', enabled: false) do
    nil
  end

  schedule(id: 'b', cron: '0 12 30 11 *', enabled: false) do
    nil
  end

  schedule(id: 'c', cron: '* * * * *', previous_time: Time.now - 120_000) do
    DT[:done] = true
  end
end

start_karafka_and_wait_until do
  DT.key?(:done)
end

topic_name = Karafka::App.config.recurring_tasks.topics.schedules.name
state_message = Karafka::Admin.read_topic(topic_name, 0, 1).last
payload = state_message.payload

assert_equal state_message.key, 'state:schedule'
assert_equal payload[:schema_version], '1.0'
assert_equal payload[:schedule_version], '1.0.1'
assert_equal payload[:type], 'schedule'
assert payload[:dispatched_at].is_a?(Float)

tasks = payload[:tasks]

# Assertions for task a
assert_equal tasks[:a][:id], 'a'
assert_equal tasks[:a][:cron], '0 12 31 12 *'
assert_equal tasks[:a][:previous_time], 0
assert tasks[:a][:next_time].is_a?(Integer)
assert_equal tasks[:a][:enabled], false

# Assertions for task b
assert_equal tasks[:b][:id], 'b'
assert_equal tasks[:b][:cron], '0 12 30 11 *'
assert_equal tasks[:b][:previous_time], 0
assert tasks[:b][:next_time].is_a?(Integer)
assert_equal tasks[:b][:enabled], false

# Assertions for task c
assert_equal tasks[:c][:id], 'c'
assert_equal tasks[:c][:cron], '* * * * *'
assert tasks[:c][:next_time].is_a?(Integer)
assert tasks[:c][:previous_time].is_a?(Integer)
assert_equal tasks[:c][:enabled], true
