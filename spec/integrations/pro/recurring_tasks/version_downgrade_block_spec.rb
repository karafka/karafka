# frozen_string_literal: true

# When using versioned schedules, we should not be able to downgrade

setup_karafka(allow_errors: %w[consumer.consume.error])

draw_routes do
  recurring_tasks do
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

setup_karafka(allow_errors: %w[consumer.consume.error])

Karafka.monitor.subscribe('error.occurred') do |event|
  DT[:errors] << event[:error]
end

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'run', cron: '* * * * *', previous_time: Time.now - 600_000) do
    nil
  end
end

start_karafka_and_wait_until do
  DT.key?(:errors)
end

assert DT[:errors].first.is_a?(Karafka::Pro::RecurringTasks::Errors::IncompatibleScheduleError)
