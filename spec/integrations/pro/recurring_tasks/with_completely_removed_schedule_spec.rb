# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to remove all the tasks and it should not trigger them ever

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

future_date = Time.now + (7 * 24 * 60 * 60) # 7 days in seconds
FUTURE_CRON = "0 12 #{future_date.day} #{future_date.month} *".freeze

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'a', cron: FUTURE_CRON, enabled: false) do
    raise
  end

  schedule(id: 'b', cron: FUTURE_CRON, enabled: false) do
    raise
  end

  schedule(id: 'c', cron: FUTURE_CRON, previous_time: Time.now - 120_000) do
    raise
  end
end

start_karafka_and_wait_until do
  sleep(10)
end

setup_karafka

# This will simulate removing whole schedule
Karafka::Pro::RecurringTasks.define('1.0.0') {}

start_karafka_and_wait_until do
  unless @dispatched
    Karafka::Pro::RecurringTasks.trigger('*')
    @dispatched = true
    sleep(5)
  end

  true
end
