# frozen_string_literal: true

# Karafka should be able to start consuming from the latest offset

setup_karafka do |config|
  config.initial_offset = 'latest'
end

before = DT.uuids(10)
after = DT.uuids(10)

# Sends some messages before starting Karafka - those should not be received
produce_many(DT.topic, before)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

# Start Karafka
Thread.new { Karafka::Server.run }

# Give it some time to boot and connect before dispatching messages
sleep(10)

# Dispatch the messages that should be consumed
produce_many(DT.topic, after)

wait_until do
  DT[0].size >= 10
end

assert_equal after, DT[0]
assert_equal 1, DT.data.size
