# frozen_string_literal: true

# When Karafka receives sigstp it should finish all the work and keep polling not to trigger
# rebalances, however the shutdown hooks should happen and new work should not be picked up

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume] << 1
    sleep(2)
  end

  def revoked
    DT[:revoked] << 1
  end

  def shutdown
    DT[:shutdown] << 1
  end
end

draw_routes(Consumer)

produce(DT.topic, '1')

Thread.new do
  sleep(0.1) until DT[:consume].size.positive?

  Process.kill('TSTP', Process.pid)

  # Give it some time to silence and run shutdowns
  sleep(0.1) until DT[:shutdown].size.positive?

  # Dispatch some more work to make sure it's not picked up
  produce(DT.topic, '1')

  sleep(1)

  Process.kill('QUIT', Process.pid)
end

start_karafka_and_wait_until { false }

assert_equal [1], DT.data[:consume], DT.data
assert_equal [1], DT.data[:shutdown], DT.data
assert DT.data[:revoked].empty?
