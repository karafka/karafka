# frozen_string_literal: true

# When enable.partition.eof is on (Eof polling strategy), reaching max_messages should still
# cap each batch at that limit even when more messages are available in the partition.
# Mirrors the batch-strategy version of this test to confirm both polling paths respect the cap.

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.max_messages = 1
  # Long enough that it would never be the exit condition
  config.max_wait_time = 5_000
  config.shutdown_timeout = 120_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:data] << message.offset
    end

    sleep(0.2)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DT[:data].size >= 20
end

time_taken = Time.now.to_f - started_at

# Would take far longer if max_messages were not respected and the whole partition was fetched
assert time_taken < 100
