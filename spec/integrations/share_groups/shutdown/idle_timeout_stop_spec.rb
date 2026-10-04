# frozen_string_literal: true

# Share group (KIP-932): we should be able to build a listener that monitors how long Karafka runs
# without consuming any new records and that stops it after the expected time by sending a stop
# signal.

setup_karafka

class IdleStopper
  include ::Karafka::Core::Helpers::Time

  def initialize(max_idle_ms)
    @last_consumed_at = nil
    @signaled = false
    @max_idle_ms = max_idle_ms
  end

  def on_consumer_consumed(_event)
    @last_consumed_at = monotonic_now
  end

  def on_connection_listener_fetch_loop(_event)
    return if @signaled
    # Measure idleness only once the share group has started delivering records
    return unless @last_consumed_at
    return if (monotonic_now - @last_consumed_at) < @max_idle_ms

    @signaled = true
    ::Process.kill("QUIT", ::Process.pid)
  end
end

Karafka::App.monitor.subscribe(IdleStopper.new(5_000))

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }
    DT[:consumed] << true
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

produce(DT.topic, "1")

# If stopping via signal from listener won't work, this spec will run forever
start_karafka_and_wait_until do
  false
end

assert_equal [true], DT[:consumed]
