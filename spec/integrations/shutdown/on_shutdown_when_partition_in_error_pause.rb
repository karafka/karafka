# frozen_string_literal: true

# When partition was paused due to an error and this pause is still lasting, on shutdown the
# `#on_shutdown` method still should be invoked

setup_karafka do |config|
  config.pause_timeout = 60 * 1_000
  config.pause_max_timeout = 60 * 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << true
    raise StandardError
  end

  def on_shutdown
    DataCollector.data[:shutdown] << true
  end
end

draw_routes(Consumer)

produce(DataCollector.topic, '1')

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 1
end

assert_equal [true], DataCollector.data[:shutdown]
