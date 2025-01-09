# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Disabled job should not run even when manually triggered

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.0.0') do
  # This one should trigger only once during the explicit trigger request
  schedule(id: 'stop', cron: '* * * * *', enabled: false) do
    DT[:disabled_done] << true
  end

  # This should never run. Alongside of this case, we also check that the command matching
  # works correctly and does not trigger this one
  schedule(id: 'crash', cron: '* * * * *', enabled: false) do
    raise
  end

  # This one will trigger fast because we set previous time in the past
  schedule(id: 'trigger', cron: '* * * * *', previous_time: Time.now - 120_000) do
    DT[:active_done] = true
  end
end

start_karafka_and_wait_until do
  if DT.key?(:active_done) && !@dispatched
    Karafka::Pro::RecurringTasks.trigger('stop')
    @dispatched = true

    true
  end

  DT.key?(:disabled_done)
end

assert_equal 1, DT[:disabled_done].size
