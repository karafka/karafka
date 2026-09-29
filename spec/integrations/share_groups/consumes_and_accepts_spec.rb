# frozen_string_literal: true

# Minimal KIP-932 share group end-to-end flow: a share consumer subscribes, receives the
# produced records (possibly across several share-fetch batches), accepts each one and the
# accepted records are not redelivered. This exercises the share-group runtime: the share client,
# the tight-loop listener, the share executor/coordinator/strategy and the consumer ack API.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[0] << message.raw_payload
      mark_as_consumed(message)
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

# Share topics do not support declarative auto-creation yet (the Declaratives routing feature is
# consumer-group only), and share consumers reject `allow.auto.create.topics`, so we create the
# topic explicitly.
Karafka::Admin.create_topic(DT.topic, 1, 1)

# Share groups default the broker-side `share.auto.offset.reset` to `latest`. Since we produce
# before the group first attaches, we set it to `earliest` so the pre-produced records are
# delivered to this brand-new share group.
admin = Rdkafka::Config.new(
  "bootstrap.servers": Karafka::App.config.kafka.fetch(:"bootstrap.servers")
).admin

admin.incremental_alter_configs(
  [
    {
      resource_type: Rdkafka::Bindings::RD_KAFKA_RESOURCE_GROUP,
      resource_name: DT.group,
      configs: [{ name: "share.auto.offset.reset", value: "earliest", op_type: 0 }]
    }
  ]
).wait(max_wait_timeout_ms: 15_000)

admin.close

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

# Every produced record should have been delivered and accepted exactly once (share groups are
# at-least-once, but an accepted record is not redelivered, so with a single consumer and no
# lock expiry we expect exactly the produced set).
assert_equal elements.sort, DT[0].sort
