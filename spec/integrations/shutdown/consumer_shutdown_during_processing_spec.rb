# frozen_string_literal: true

# Karafka should call shutdown hooks during server termination

setup_karafka

class ShutdownHookConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload

      # After processing first message, stop the server to test shutdown hooks
      Thread.new { Karafka::Server.stop } if message.raw_payload == "trigger_stop"
    end
  end

  def shutdown
    DT[:shutdown_hook_called] = true
    DT[:shutdown_message] = "Graceful shutdown initiated"
  end
end

draw_routes(ShutdownHookConsumer)

produce(DT.topic, "trigger_stop")

start_karafka_and_wait_until do
  DT.key?(:shutdown_hook_called)
end

# Verify the shutdown process worked correctly
assert DT[:consumed].include?("trigger_stop")
assert DT[:shutdown_hook_called]
assert_equal "Graceful shutdown initiated", DT[:shutdown_message]
