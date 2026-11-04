# frozen_string_literal: true

# Share group (KIP-932): when SIGTSTP (quiet) is quickly followed by SIGTERM (stop), Karafka
# should handle the transition cleanly, running the shutdown hooks exactly once.

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

  # First quiet the process
  Process.kill("TSTP", Process.pid)

  # Give it a moment then stop
  sleep(1)

  Process.kill("TERM", Process.pid)
end

start_karafka_and_wait_until { false }

assert_equal [1], DT[:consume]
assert_equal [1], DT[:shutdown]
