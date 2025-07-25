# frozen_string_literal: true

# When we have non-critical error happening couple times and we use constant backoff, Karafka
# should not increase the backoff time with each occurrence.

setup_karafka(allow_errors: true) do |config|
  config.max_wait_time = 100
  config.max_messages = 1
  config.pause_with_exponential_backoff = false
  config.pause_timeout = 100
  config.pause_max_timeout = 100
end

class Consumer < Karafka::BaseConsumer
  def initialized
    DT[0] << Time.now.to_f
  end

  def consume
    DT[0] << Time.now.to_f

    raise StandardError
  end
end

draw_routes(Consumer)

produce(DT.topic, '0')

start_karafka_and_wait_until do
  DT[0].size >= 10
end

# Backoff time before next exception occurrence (not before resume).
# We give it some tolerance as we need to resume +  we need to compensate for running several
# specs at the same time in parallel in the CI
BACKOFF_RANGE = 0..1.5

previous = nil

DT[0].each do |timestamp|
  unless previous
    previous = timestamp
    next
  end

  backoff = (timestamp - previous)

  assert_equal(
    true,
    BACKOFF_RANGE.include?(backoff),
    "Expected #{backoff} to be in #{BACKOFF_RANGE}"
  )

  previous = timestamp
end
