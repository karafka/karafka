# frozen_string_literal: true

# We should be able to disable and enable back all the jobs in one go

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define('2.0.0') do
  10.times do |i|
    schedule(id: "j#{i}", cron: '* * * * *', previous_time: Time.now - 120_000) do
      DT[:"j#{i}"] << true
    end
  end
end

start_karafka_and_wait_until do
  Karafka::Pro::RecurringTasks.disable('*')
  sleep(1)
  Karafka::Pro::RecurringTasks.enable('*')
  sleep(1)
  Karafka::Pro::RecurringTasks.trigger('*')

  Array.new(10) { |i| DT[:"j#{i}"] }.all? { |accu| accu.size >= 5 }
end
