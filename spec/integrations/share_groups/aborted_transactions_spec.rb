# frozen_string_literal: true

# Share group (KIP-932) with the `share.isolation.level` group config set to `read_committed` does
# not deliver records from aborted transactions (the broker default is `read_uncommitted`).

setup_karafka do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:offsets] << message.offset
      DT[:payloads] << message.raw_payload
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

admin = Rdkafka::Config.new(
  "bootstrap.servers": Karafka::App.config.kafka.fetch(:"bootstrap.servers")
).admin

admin.incremental_alter_configs(
  [
    {
      resource_type: Rdkafka::Bindings::RD_KAFKA_RESOURCE_GROUP,
      resource_name: DT.group,
      configs: [{ name: "share.isolation.level", value: "read_committed", op_type: 0 }]
    }
  ]
).wait(max_wait_timeout_ms: 15_000)

admin.close

aborted = DT.uuids(10)

2.times do
  # Fail the transaction just for the sake of having aborted data
  Karafka::App.producer.transaction do
    Karafka::App.producer.produce_many_sync(
      aborted.map { |payload| { topic: DT.topic, payload: payload } }
    )

    raise(WaterDrop::AbortTransaction)
  end
end

elements = DT.uuids(10)

# This will be successful
Karafka::App.producer.transaction do
  Karafka::App.producer.produce_many_sync(
    elements.map { |payload| { topic: DT.topic, payload: payload } }
  )
end

start_karafka_and_wait_until do
  if (DT[:payloads] & elements).size >= 10
    DT[:consumed_at] = Time.now unless DT.key?(:consumed_at)

    Time.now - DT[:consumed_at] > 5
  else
    false
  end
end

assert_equal elements.sort, DT[:payloads].sort
assert_equal (22..31).to_a, DT[:offsets].sort
