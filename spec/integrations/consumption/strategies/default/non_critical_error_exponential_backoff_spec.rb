# frozen_string_literal: true

# When we have non-critical error happening couple times and we use exponential backoff, Karafka
# should increase the backoff time with each occurrence until max backoff.

setup_karafka(allow_errors: true) do |config|
  config.max_wait_time = 100
  config.max_messages = 1
  config.pause.with_exponential_backoff = true
  config.pause.max_timeout = 5_000
  config.pause.timeout = 200
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed_at] << Time.now.to_f

    raise StandardError
  end
end

Karafka::App.monitor.subscribe("consumer.consuming.pause") do |event|
  next if event[:manual]

  DT[:pauses] << { timeout: event[:timeout], attempt: event[:attempt] }
end

draw_routes(Consumer)

produce(DT.topic, "0")

start_karafka_and_wait_until do
  DT[:pauses].size >= 8
end

timeouts = DT[:pauses].map { |pause| pause[:timeout] }
attempts = DT[:pauses].map { |pause| pause[:attempt] }

assert_equal([400, 800, 1_600, 3_200, 5_000, 5_000, 5_000, 5_000], timeouts.first(8))
assert_equal((attempts.first...(attempts.first + attempts.size)).to_a, attempts)

# Wall-clock gaps on a loaded runner can only be longer than the pause, never shorter, so we
# check only that the next attempt did not start before the backoff ended
DT[:consumed_at].first(timeouts.size + 1).each_cons(2).with_index do |(previous, current), index|
  backoff = timeouts[index] / 1_000.0

  assert(
    current - previous >= backoff - 0.05,
    "Expected #{current - previous} to be at least #{backoff}"
  )
end
