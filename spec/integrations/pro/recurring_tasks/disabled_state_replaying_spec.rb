# frozen_string_literal: true

# When we have an active schedule that got disabled, after a re-run we should be able to
# recover its inactive state

setup_karafka

draw_routes do
  recurring_tasks do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.0.0') do
  # This should never run. Alongside of this case, we also check that the command matching
  # works correctly and does not trigger this one
  schedule(id: 'crash', cron: '* * * * *', previous_time: Time.now - 600_000) do
    if DT.key?(:rerun)
      raise
    else
      DT[:run] = true
    end
  end
end

start_karafka_and_wait_until(reset_status: true) do
  if DT.key?(:run)
    Karafka::Pro::RecurringTasks::Dispatcher.command('disable', 'crash')
    sleep(1)
    DT[:done] = true
  end

  DT.key?(:done)
end

DT[:rerun] = true

setup_karafka

start_karafka_and_wait_until do
  sleep(5)
end
