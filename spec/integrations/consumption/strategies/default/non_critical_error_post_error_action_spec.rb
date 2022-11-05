# frozen_string_literal: true

# When we have non-critical error we should be able to do some "post error" operations without
# breaking the backoff Karafka offers

setup_karafka(allow_errors: true) do |config|
  config.max_wait_time = 100
  config.max_messages = 1
  config.pause_with_exponential_backoff = false
  config.pause_timeout = 100
  config.pause_max_timeout = 100
  config.concurrency = 1
end

module Test
  Error = Class.new(StandardError)

  class << self
    def clean!
      DT[:cleans] << Thread.current.object_id
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:threads] << Thread.current.object_id

    raise Test::Error
  end
end

draw_routes(Consumer)

# Cleanup after this error occurs from a block
Karafka.monitor.subscribe 'error.occurred' do |event|
  next unless event[:error].is_a?(Test::Error)

  ::Test.clean!
end

class Cleaner
  def on_error_occurred(event)
    return unless event[:error].is_a?(Test::Error)

    ::Test.clean!
  end
end

# Cleanup from instance
Karafka.monitor.subscribe(Cleaner.new)

produce(DT.topic, '0')

start_karafka_and_wait_until do
  DT[:threads].size >= 2
end

assert_equal DT[:cleans].uniq, DT[:threads].uniq
assert_equal 1, DT[:cleans].uniq.size
assert_equal 1, DT[:threads].uniq.size
# Two subscribers mean twice the cleaning
assert_equal DT[:cleans].count, DT[:threads].count * 2
