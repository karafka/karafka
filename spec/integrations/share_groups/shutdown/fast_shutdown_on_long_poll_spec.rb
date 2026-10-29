# frozen_string_literal: true

# Share group (KIP-932) listener does not wait for a full long poll when shutdown is issued: like for
# consumer groups the poll is done in short slices and stops early. No assertions are needed as it
# would just wait (almost) forever if not working correctly.

setup_karafka do |config|
  config.shutdown_timeout = 150_000_000
  config.max_wait_time = 100_000_000
  config.internal.swarm.node_report_timeout = 200_000_000
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[0] << message.raw_payload
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

2.times { produce(DT.topic, "1") }

start_karafka_and_wait_until do
  if DT[0].size >= 2
    sleep(2)
    true
  else
    false
  end
end
