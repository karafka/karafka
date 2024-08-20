# frozen_string_literal: true

# When tasks are triggered, by default it should publish events to the logs topic
# This spec will hang if logs are not published

setup_karafka

class CountConsumer < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[:messages] << true
    end
  end
end

draw_routes do
  recurring_tasks do
    max_wait_time 500
  end

  topic Karafka::App.config.recurring_tasks.topics.logs do
    consumer CountConsumer
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

  DT[:messages].count >= 3
end
