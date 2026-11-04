# frozen_string_literal: true

# Share group (KIP-932): when Karafka receives SIGINT, it should stop after finishing the work and
# running the shutdown hooks.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| mark_as_accepted(message) }
    DT[:consumed] << true
  end

  def shutdown
    DT[:shutdown] << true
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
  sleep(0.1) while DT[:consumed].empty?

  Process.kill("INT", Process.pid)
end

# In case of a failure Karafka will not stop and will be killed by the runner
start_karafka_and_wait_until { false }

assert_equal [true], DT[:consumed]
assert_equal [true], DT[:shutdown]
