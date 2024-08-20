# frozen_string_literal: true

# When we start cron and publish several events, the state should always be published after
# each command execution. This allows us to make assumptions about the topic data structure when
# buildings things like UI.

setup_karafka

draw_routes do
  recurring_tasks do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'run', cron: '* * * * *', enabled: false) do
    DT[:attempts] << true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  Karafka::Pro::RecurringTasks.disable('run')
  sleep(1)
  Karafka::Pro::RecurringTasks.enable('run')
  sleep(1)
  Karafka::Pro::RecurringTasks.trigger('run')
  sleep(1)

  DT[:attempts].size >= 10
end

previous = nil

Karafka::Admin
  .read_topic(Karafka::App.config.recurring_tasks.topics.schedules, 0, 21)
  .map(&:key)
  .each do |event|
    assert previous != event

    previous = event
  end
