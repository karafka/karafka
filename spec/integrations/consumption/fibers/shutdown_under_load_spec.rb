# frozen_string_literal: true

# When running the fibers workers backend, a graceful shutdown initiated while a fiber job is
# in-flight should let the job finish and run the shutdown hooks

setup_karafka do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Trigger the stop while we are still processing
      Thread.new { Karafka::Server.stop } if message.raw_payload == "trigger_stop"

      # Scheduler-aware in-flight work that shutdown must wait for
      sleep(1)

      DT[:consumed] << message.raw_payload
    end
  end

  def shutdown
    DT[:shutdown_hook_called] = true
  end
end

draw_routes(Consumer)

produce(DT.topic, "trigger_stop")

start_karafka_and_wait_until do
  DT.key?(:shutdown_hook_called)
end

# In-flight fiber job finished gracefully before shutdown completed
assert DT[:consumed].include?("trigger_stop")
assert DT[:shutdown_hook_called]
