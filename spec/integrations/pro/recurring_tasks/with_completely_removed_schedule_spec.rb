# frozen_string_literal: true

# We should be able to remove all the tasks and it should not trigger them ever

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'a', cron: '0 12 31 12 *', enabled: false) do
    raise
  end

  schedule(id: 'b', cron: '0 12 31 12 *', enabled: false) do
    raise
  end

  schedule(id: 'c', cron: '0 12 31 12 *', previous_time: Time.now - 120_000) do
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
