# frozen_string_literal: true

# Karafka Admin API should work correctly with KIP-848 consumer groups
# This tests that AdminClient operations like describe work with the new protocol

setup_karafka(consumer_group_protocol: true)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

# Produce some messages
messages = DT.uuids(10)
produce_many(DT.topic, messages)

start_karafka_and_wait_until do
  DT[:consumed].size >= 10
end

assert_equal 10, DT[:consumed].size

# Verify Admin API read operations work with KIP-848 consumer groups
lags = Karafka::Admin.read_lags_with_offsets({ DT.consumer_group => [DT.topic] })

assert lags.key?(DT.consumer_group), 'Should be able to read lags for KIP-848 consumer group'
assert lags[DT.consumer_group].key?(DT.topic), 'Should have topic info in lags'
