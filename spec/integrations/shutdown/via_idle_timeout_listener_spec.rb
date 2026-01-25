# frozen_string_literal: true

# We should be able to build a listener that will monitor how long karafka is running without
# receiving any new messages and that it will stop after the expected time by sending the stop
# signal

setup_karafka

class IdleStopper
  include ::Karafka::Core::Helpers::Time

  # 60 seconds by default
  def initialize(max_idle_ms = 15_000)
    @last_message_received_at = monotonic_now
    @signaled = false
    @max_idle_ms = max_idle_ms
  end

  def on_connection_listener_fetch_loop_received(event)
    return if @signaled

    now = monotonic_now

    unless event[:messages_buffer].empty?
      @last_message_received_at = now

      return
    end

    return if (now - @last_message_received_at) < @max_idle_ms

    @signaled = true
    ::Process.kill("QUIT", ::Process.pid)
  end
end

Karafka::App.monitor.subscribe(IdleStopper.new(15_000))

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

# If stopping via signal from listener won't work, this spec will run forever
start_karafka_and_wait_until do
  false
end
