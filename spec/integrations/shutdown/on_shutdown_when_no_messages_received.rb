# frozen_string_literal: true

# When we received no messages, shutdown should not happen

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << 1
  end

  def shutdown
    DT[0] << 1
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  sleep(2)
  true
end

assert_equal 0, DT[0].size
