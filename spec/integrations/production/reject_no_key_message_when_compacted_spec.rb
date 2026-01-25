# frozen_string_literal: true

# Kafka should reject a message on a compacted topic, when this message does not contain a key

setup_karafka

draw_routes do
  topic DT.topic do
    config(
      partitions: 1,
      "cleanup.policy": "compact"
    )
    active false
  end
end

errors = []

begin
  Karafka.producer.produce_sync(topic: DT.topic, payload: "test1")
rescue WaterDrop::Errors::ProduceError => e
  errors << e
end

assert_equal errors.last.cause.code, :invalid_record

Karafka.producer.produce_sync(topic: DT.topic, payload: "test1", key: "1")

Karafka.producer.close
