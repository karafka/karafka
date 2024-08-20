# frozen_string_literal: true

# We should be able to build up a schedule with recurring tasks that we can use

setup_karafka

draw_routes(create_topics: false) do
  recurring_tasks
end

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: 'cleanup', cron: '0 0 * * *') do
    puts 'Cleanup'
  end

  schedule(id: 'send_emails', cron: '*/5 * * * *') do
    puts 'Email'
  end
end

# It should be stored as the current schedule
assert !Karafka::Pro::RecurringTasks.schedule.nil?
