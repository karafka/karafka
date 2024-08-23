# frozen_string_literal: true

# When using versioned schedules, we should be able to upgrade
# There should be no exceptions or crashes and new schedule should work

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.1.0') do
  schedule(id: 'run', cron: '* * * * *', previous_time: Time.now - 600_000) do
    DT[:done] = true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  unless @dispatched
    Karafka::Pro::RecurringTasks.trigger('run')
    @dispatched = true
  end

  DT.key?(:done)
end

setup_karafka

Karafka::Pro::RecurringTasks.define('1.2.0') do
  schedule(id: 'run', cron: '* * * * *') do
    DT[:done2] = true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  unless @dispatched2
    sleep(2)
    Karafka::Pro::RecurringTasks.trigger('run')
    @dispatched2 = true
  end

  DT.key?(:done2)
end
