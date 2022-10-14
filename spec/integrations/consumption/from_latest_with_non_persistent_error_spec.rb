# frozen_string_literal: true

# When we connect for the first time with cluster from a new consumer group and start consuming
# from earliest and an error occurs on a first message, we should pause and retry consumption
# until we can process this message. No messages should be skipped or ignored.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
  # We sleep more to check if when sleeping other topic messages are processed
  config.pause_timeout = 1_000
  config.pause_max_timeout = 1_000
  config.pause_with_exponential_backoff = false
  config.initial_offset = 'latest'
end

before = DT.uuids(2)
after = DT.uuids(10)

# Sends some messages before starting Karafka - those should not be received
produce_many(DT.topic, before)

class Consumer < Karafka::BaseConsumer
  def consume
    @retry ||= 0
    @retry += 1

    raise StandardError if @retry < 3

    messages.each do |message|
      DT[0] << message.raw_payload
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
