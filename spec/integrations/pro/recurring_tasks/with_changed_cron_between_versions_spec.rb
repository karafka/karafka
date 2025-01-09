# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When cron changes between versions, we should be using the new one.

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

past_date = Time.now + (7 * 24 * 60 * 60)
PAST_CRON = "0 0 #{past_date.day} #{past_date.month} *".freeze

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'run', cron: PAST_CRON, previous_time: Time.now - 60_000) do
    # Should never run until cron schedule is updated
    raise
  end
end

start_karafka_and_wait_until(reset_status: true) do
  sleep(10)
end

setup_karafka

Karafka::Pro::RecurringTasks.define('1.2.0') do
  schedule(id: 'run', cron: '* * * * *') do
    DT[:done] = true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  DT.key?(:done)
end
