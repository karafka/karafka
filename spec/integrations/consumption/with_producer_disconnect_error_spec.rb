# frozen_string_literal: true

# When Karafka producer (WaterDrop) disconnects it should instrument and reconnect.
# @note Here we force the disconnect by setting the `connections.max.idle.ms` to a really low
#   value. Usually you have it higher and it may be, that it is Kafka that is disconnecting.
#   In such cases you can ignore those errors as the reconnect will happen.

setup_karafka(allow_errors: true) do |config|
  config.kafka.merge!('connections.max.idle.ms': 1_000)
end

Karafka.producer.monitor.subscribe('error.occurred') do |event|
  DT[:errors] << event[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, ['1'])

sleep(5)

produce_many(DT.topic, ['1'])

start_karafka_and_wait_until do
  DT[0].size >= 2 && DT.key?(:errors)
end

assert_equal 2, DT[0].size
assert DT.key?(:errors)
