# frozen_string_literal: true

# Producer should handle messages near the broker size limit correctly.
# A ~500KB payload (below the default 1MB limit) should be produced and consumed intact.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:payloads] << message.raw_payload
      DT[:sizes] << message.raw_payload.bytesize
    end
  end
end

draw_routes(Consumer)

# Create a ~500KB payload
large_payload = "x" * 500_000

produce(DT.topic, large_payload)

start_karafka_and_wait_until do
  DT[:payloads].size >= 1
end

# Verify payload arrived intact
assert_equal 1, DT[:payloads].size
assert_equal large_payload.bytesize, DT[:sizes].first
assert_equal large_payload, DT[:payloads].first
