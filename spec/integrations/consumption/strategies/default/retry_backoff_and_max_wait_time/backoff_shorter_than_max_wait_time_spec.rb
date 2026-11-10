# frozen_string_literal: true

# Paused partitions are resumed once per listener loop, before polling, and that poll can block for
# up to `max_wait_time`. A retry backoff shorter than `max_wait_time` is therefore not honored: the
# retry runs at the first loop after the pause expires, never sooner than `max_wait_time` and in
# practice later (about 2s with the default 1s `max_wait_time`).
# The pause instrumentation still reports the configured backoff, not the real delay.

setup_karafka(allow_errors: true) do |config|
  config.max_wait_time = 1_000
  config.max_messages = 1
  config.pause.with_exponential_backoff = false
  config.pause.timeout = 200
  config.pause.max_timeout = 200
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed_at] << Time.now.to_f

    raise StandardError
  end
end

Karafka::App.monitor.subscribe("consumer.consuming.pause") do |event|
  next if event[:manual]

  DT[:timeouts] << event[:timeout]
end

draw_routes(Consumer)

produce(DT.topic, "0")

start_karafka_and_wait_until do
  DT[:consumed_at].size >= 5
end

assert(DT[:timeouts].size >= DT[:consumed_at].size - 1, DT[:timeouts])
assert(DT[:timeouts].all?(200), DT[:timeouts])

DT[:consumed_at].each_cons(2) do |previous, current|
  assert(
    current - previous >= 1.0 - 0.05,
    "Expected #{current - previous} to be at least the 1s max_wait_time"
  )
end
