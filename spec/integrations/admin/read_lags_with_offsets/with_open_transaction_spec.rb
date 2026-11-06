# frozen_string_literal: true

# Lags should be computed against the last stable offset under the default `read_committed`
# isolation level, so messages of an open transaction do not count, and against the high
# watermark under `read_uncommitted`

setup_karafka

draw_topics do
  topic DT.topic do
    partitions 1
  end
end

produce_many(DT.topic, DT.uuids(10))

Karafka::Admin.seek_consumer_group(DT.group, { DT.topic => { 0 => 0 } })

transactional_producer = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = {
    "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092"),
    "transactional.id": SecureRandom.uuid
  }
end

transaction = Thread.new do
  transactional_producer.transaction do
    5.times { transactional_producer.produce_sync(topic: DT.topic, payload: DT.uuid) }
    DT[:open] = true

    sleep(0.1) until DT.key?(:measured)

    raise(WaterDrop::AbortTransaction)
  end
end

sleep(0.1) until DT.key?(:open)

committed = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic] })

uncommitted = Karafka::Admin
  .new(kafka: { "isolation.level": "read_uncommitted" })
  .read_lags_with_offsets({ DT.group => [DT.topic] })

DT[:measured] = true
transaction.join
transactional_producer.close

assert_equal({ offset: 0, lag: 10 }, committed.fetch(DT.group).fetch(DT.topic).fetch(0))
assert_equal({ offset: 0, lag: 15 }, uncommitted.fetch(DT.group).fetch(DT.topic).fetch(0))
