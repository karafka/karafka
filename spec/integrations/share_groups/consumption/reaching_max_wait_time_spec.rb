# frozen_string_literal: true

# Share group (KIP-932) polls do not wait the whole `max_wait_time` to fill up `max_messages` like
# consumer groups do. The share consumer returns records as soon as it acquires any, so a few
# records are processed right away, way before the long max wait time passes.

setup_karafka do |config|
  config.max_messages = 200
  config.max_wait_time = 20_000
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:data] << message.raw_payload
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

3.times { produce(DT.topic, "data") }

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DT[:data].size >= 3
end

time_taken = Time.now.to_f - started_at

assert time_taken < 20, time_taken
assert_equal 3, DT[:data].size
