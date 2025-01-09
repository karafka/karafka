# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When we decide to use recurring tasks and we have a job that never migrated from anything, it
# should work
#
# This spec may last up to 1 minute but we do want this as we want to test that it is invoked
# without explicit request to run

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'stop', cron: '* * * * *') do
    DT[:done] = true
  end
end

start_karafka_and_wait_until do
  DT.key?(:done)
end
