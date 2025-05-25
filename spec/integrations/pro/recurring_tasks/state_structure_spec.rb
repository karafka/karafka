# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
