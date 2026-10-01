# frozen_string_literal: true

# Share group (KIP-932) consumption keeps working when the producer (WaterDrop) idle connections
# get closed. Here we force the disconnects by setting `connections.max.idle.ms` to a really low
# value and produce after the connections went idle, also from within the share consumer.

setup_karafka(allow_errors: true) do |config|
  config.kafka.merge!("connections.max.idle.ms": 1_000)
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload

      producer.produce_sync(topic: DT.topic, payload: "from-consumer") if message.raw_payload == "3"

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

produce_many(DT.topic, ["1"])

sleep(3)

produce_many(DT.topic, ["2"])

sleep(2)

produce_many(DT.topic, ["3"])

start_karafka_and_wait_until do
  DT[:consumed].size >= 4
end

assert_equal %w[1 2 3 from-consumer], DT[:consumed].sort
