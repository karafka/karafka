# frozen_string_literal: true

# Share group (KIP-932) shutdown: a stop requested while a record is being processed lets the
# batch finish and then runs the `#shutdown` hook.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
      mark_as_accepted(message)

      # After processing the first record, stop the server to test the shutdown hook
      Thread.new { Karafka::Server.stop } if message.raw_payload == "trigger_stop"
    end
  end

  def shutdown
    DT[:shutdown_hook_called] = true
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce(DT.topic, "trigger_stop")

start_karafka_and_wait_until do
  DT.key?(:shutdown_hook_called)
end

assert DT[:consumed].include?("trigger_stop")
assert DT[:shutdown_hook_called]
