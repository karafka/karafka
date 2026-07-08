# frozen_string_literal: true

# Kafka should reject a message on a compacted topic, when this message does not contain a key

setup_karafka

draw_topics do
  topic DT.topic do
    partitions 1
    config("cleanup.policy": "compact")
  end
end

draw_routes do
  topic DT.topic do
    active false
  end
end

errors = []

begin
  Karafka.producer.produce_sync(topic: DT.topic, payload: "test1")
rescue WaterDrop::Errors::ProduceError => e
  errors << e
end

assert_equal :invalid_record, errors.last.cause.code

Karafka.producer.produce_sync(topic: DT.topic, payload: "test1", key: "1")

Karafka.producer.close
