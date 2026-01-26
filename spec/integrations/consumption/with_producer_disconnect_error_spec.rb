# frozen_string_literal: true

# When Karafka producer (WaterDrop) disconnects it should reconnect automatically.
# @note Here we force the disconnect by setting the `connections.max.idle.ms` to a really low
#   value. With librdkafka updates, planned disconnections no longer emit "all brokers down"
#   errors, so we test that the producer continues working after forced disconnection.

setup_karafka(allow_errors: true) do |config|
  config.kafka.merge!("connections.max.idle.ms": 1_000)
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, ["1"])

sleep(5)

produce_many(DT.topic, ["2"])

# Wait longer to allow potential disconnect/reconnect to happen again
sleep(2)

# Produce another message after potential disconnect to verify producer still works
produce_many(DT.topic, ["3"])

start_karafka_and_wait_until do
  DT[0].size >= 3
end

assert_equal 3, DT[0].size
