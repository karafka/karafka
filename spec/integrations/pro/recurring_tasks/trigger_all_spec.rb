# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to trigger all tasks even if they are suppose to run once a year

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'a', cron: '0 12 31 12 *', enabled: false) do
    DT[:a] = true
  end

  schedule(id: 'b', cron: '0 12 31 12 *', enabled: false) do
    DT[:b] = true
  end

  schedule(id: 'c', cron: '0 12 31 12 *', previous_time: Time.now - 120_000) do
    DT[:c] = true
  end
end

start_karafka_and_wait_until do
  unless @dispatched
    Karafka::Pro::RecurringTasks.trigger('*')
    @dispatched = true
  end

  DT.key?(:a) && DT.key?(:b) && DT.key?(:c)
end
