# frozen_string_literal: true

# Share group (KIP-932) errors in `#consume` are reported to all the `error.occurred` subscribers
# (block and instance ones) from the worker thread that ran the consumption, so "post error"
# operations can run there while the records are still released and redelivered.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
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

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:threads] << Thread.current.object_id
    DT[:deliveries] << messages.first.delivery_count

    raise Test::Error
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

# Cleanup after this error occurs from a block
Karafka.monitor.subscribe "error.occurred" do |event|
  next unless event[:error].is_a?(Test::Error)

  Test.clean!
end

class Cleaner
  def on_error_occurred(event)
    return unless event[:error].is_a?(Test::Error)

    ::Test.clean!
  end
end

# Cleanup from instance
Karafka.monitor.subscribe(Cleaner.new)

setup_share_group

produce(DT.topic, "0")

start_karafka_and_wait_until do
  DT[:threads].size >= 2
end

assert_equal [1, 2], DT[:deliveries].first(2)
assert_equal DT[:cleans].uniq, DT[:threads].uniq
assert_equal 1, DT[:cleans].uniq.size
assert_equal 1, DT[:threads].uniq.size
# Two subscribers mean twice the cleaning
assert_equal DT[:cleans].size, DT[:threads].size * 2
