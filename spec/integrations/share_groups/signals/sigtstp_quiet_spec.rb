# frozen_string_literal: true

# Share group (KIP-932): when Karafka receives SIGTSTP it should finish the in-flight work and run
# the shutdown hooks, but new records should not be picked up until it is stopped.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:consume] << 1
    sleep(2)
    messages.each { |message| mark_as_accepted(message) }
  end

  def shutdown
    DT[:shutdown] << 1
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce(DT.topic, "1")

Thread.new do
  sleep(0.1) while DT[:consume].empty?

  Process.kill("TSTP", Process.pid)

  # Give it some time to silence and run shutdowns
  sleep(0.1) while DT[:shutdown].empty?

  # Dispatch some more work to make sure it's not picked up
  produce(DT.topic, "1")

  sleep(2)

  Process.kill("QUIT", Process.pid)
end

start_karafka_and_wait_until { false }

assert_equal [1], DT[:consume]
assert_equal [1], DT[:shutdown]
