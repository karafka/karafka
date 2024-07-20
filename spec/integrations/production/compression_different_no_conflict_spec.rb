# frozen_string_literal: true

# Kafka allows to use different default compression and per producer compression type
# It should be supported in Karafka

setup_karafka

draw_routes do
  topic DT.topic do
    config(
      partitions: 1,
      'compression.type': 'lz4'
    )
    active false
  end
end

variant1 = Karafka.producer.with(
  topic_config: {
    'compression.codec': 'lz4'
  }
)

variant2 = Karafka.producer.with(
  topic_config: {
    'compression.codec': 'zstd'
  }
)

variant1.produce_sync(topic: DT.topic, payload: 'test1')
variant2.produce_sync(topic: DT.topic, payload: 'test2')

Karafka.producer.close

messages = Karafka::Admin.read_topic(DT.topic, 0, 2)
assert_equal messages[0].raw_payload, 'test1'
assert_equal messages[1].raw_payload, 'test2'
