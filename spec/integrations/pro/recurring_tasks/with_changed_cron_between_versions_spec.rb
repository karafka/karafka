# frozen_string_literal: true

# When cron changes between versions, we should be using the new one.

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'run', cron: '0 0 1 1 *', previous_time: Time.now - 60_000) do
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
