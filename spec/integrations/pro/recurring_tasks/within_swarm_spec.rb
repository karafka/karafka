# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Recurring tasks should work from a swarm. If they don't this spec will run forever

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

READER, WRITER = IO.pipe

Karafka::Pro::RecurringTasks.define('1.0.0') do
  schedule(id: SecureRandom.uuid, cron: '* * * * *', enabled: true) do
    WRITER.puts('1')
    WRITER.flush
  end
end

start_karafka_and_wait_until(mode: :swarm) do
  READER.gets && sleep(1)
end
