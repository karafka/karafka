# frozen_string_literal: true

# Share group (KIP-932): once quiet is reached, the share listener stays quiet (not stopped), no
# new records are consumed, yet `statistics.emitted` keeps flowing.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
      mark_as_accepted(message)
    end
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

Karafka.monitor.subscribe("statistics.emitted") do
  DT[:stats] << Time.now.to_f
end

produce(DT.topic, "1")

Thread.new do
  sleep(0.1) while DT[:consumed].empty?

  Karafka::Server.quiet

  sleep(0.1) until Karafka::Server.listeners.all?(&:quiet?)

  quiet_at = Time.now.to_f

  produce(DT.topic, "2")

  5.times do
    sleep(1)
    assert Karafka::Server.listeners.none?(&:stopped?)
    assert Karafka::Server.listeners.none?(&:stopping?)
  end

  assert Karafka::Server.listeners.all?(&:quiet?)
  assert_equal %w[1], DT[:consumed]
  assert DT[:stats].any? { |at| at > quiet_at + 1 }

  DT[:checked] = true

  Karafka::Server.stop
end

start_karafka_and_wait_until do
  false
end

assert DT[:checked]
