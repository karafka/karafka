# frozen_string_literal: true

# Share group (KIP-932) consumers with a small `max_messages` and a long `max_wait_time` process
# records in batches of at most `max_messages` without ever waiting for the max wait time.

setup_karafka do |config|
  config.max_messages = 1
  # It should never go that far
  config.max_wait_time = 20_000
  config.shutdown_timeout = 60_000
end

class Consumer < Karafka::ShareConsumer
  def consume
    DT[:sizes] << messages.size

    messages.each do |message|
      DT[:data] << message.raw_payload
      mark_as_accepted(message)
    end

    sleep(0.1)
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

produce_many(DT.topic, DT.uuids(100))

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DT[:data].size >= 20
end

time_taken = Time.now.to_f - started_at

# If it would wait for the max wait time, 20 batches would take a really long time
assert time_taken < 20, time_taken
assert_equal [1], DT[:sizes].uniq
