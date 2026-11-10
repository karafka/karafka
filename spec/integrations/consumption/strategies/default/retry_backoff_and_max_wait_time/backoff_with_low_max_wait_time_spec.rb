# frozen_string_literal: true

# With `max_wait_time` lower than the retry backoff, the listener loops often enough to resume the
# paused partition shortly after `pause.timeout` ends, so the gaps between retries follow the
# backoff instead of being rounded up to the default 1s `max_wait_time`.

setup_karafka(allow_errors: true) do |config|
  config.max_wait_time = 100
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
  DT[:consumed_at].size >= 10
end

assert(DT[:timeouts].all?(200), DT[:timeouts])

gaps = DT[:consumed_at].each_cons(2).map { |previous, current| current - previous }

gaps.each do |gap|
  assert(gap >= 0.2 - 0.05, "Expected #{gap} to be at least the 0.2s backoff")
end

# The median tolerates single slow loops on a loaded runner while still showing that retries
# are not rounded up to the default 1s max_wait_time
median = gaps.sort[gaps.size / 2]

assert(median < 1.0, "Expected median gap #{median} to be below 1s")
