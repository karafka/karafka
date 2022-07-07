# frozen_string_literal: true

# When we received no messages, shutdown should not happen

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector[0] << 1
  end

  def shutdown
    DataCollector[0] << 1
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  sleep(2)
  true
end

assert_equal 0, DataCollector[0].size
