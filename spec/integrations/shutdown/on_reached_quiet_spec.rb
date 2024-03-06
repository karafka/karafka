# frozen_string_literal: true

# When we have reached quiet state, we should still be subscribed to what we had

setup_karafka

produce(DT.topic, '1')

class Consumer < Karafka::BaseConsumer
  def consume
    DT[SecureRandom.uuid] = true
    sleep(1)
  end
end

draw_routes(create_topics: false) do
  5.times do |i|
    consumer_group "gr#{i}" do
      topic DT.topic do
        consumer Consumer
      end
    end
  end
end

Thread.new do
  sleep(0.1) until DT.data.keys.size >= 5

  # Move to quiet
  Karafka::Server.quiet

  # Wait and make sure we are polling
  10.times do
    sleep(1)
    assert Karafka::Server.listeners.none?(&:stopped?)
    assert Karafka::Server.listeners.none?(&:stopping?)
  end

  assert Karafka::Server.listeners.all?(&:quiet?)

  Karafka::Server.stop
end

start_karafka_and_wait_until do
  false
end
