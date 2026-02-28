# frozen_string_literal: true

# When SIGTSTP (quiet) is followed quickly by SIGTERM (stop), Karafka should handle
# the transition cleanly. Shutdown hooks should be called and the process should exit.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume] << 1
    sleep(2)
  end

  def shutdown
    DT[:shutdown] << 1
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

Thread.new do
  sleep(0.1) until DT[:consume].size.positive?

  # First quiet the process
  Process.kill("TSTP", Process.pid)

  # Give it a moment then stop
  sleep(1)

  Process.kill("TERM", Process.pid)
end

start_karafka_and_wait_until { false }

# Consumer should have processed at least once
assert_equal [1], DT[:consume]
# Shutdown hooks should have been called exactly once
assert_equal [1], DT[:shutdown]
