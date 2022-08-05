# frozen_string_literal: true

# Karafka should be able to start consuming from the latest offset

setup_karafka do |config|
  config.initial_offset = 'latest'
end

before = Array.new(10) { SecureRandom.uuid }
after = Array.new(10) { SecureRandom.uuid }

# Sends some messages before starting Karafka - those should not be received
before.each { |number| produce(DT.topic, number) }

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
after.each { |number| produce(DT.topic, number) }

wait_until do
  DT[0].size >= 10
end

assert_equal after, DT[0]
assert_equal 1, DT.data.size
