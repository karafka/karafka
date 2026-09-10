# frozen_string_literal: true

# Share consumers (KIP-932) reject a number of regular-consumer client properties (offsets and
# assignment are broker-managed, no static membership, poll-based liveness does not apply), so
# subscription groups built for share groups must not carry the consumer-group only injections
# (auto.offset.reset, enable.auto.offset.store, max.poll.interval.ms, group.instance.id) while
# consumer groups keep receiving them unchanged. Share-specific keys (max.poll.records,
# share.acknowledgement.mode) must survive the share attributes scope filtering.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group "cg" do
    topic "regular" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "sg" do
    topic "share-topic" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

cg_kafka = Karafka::App.routes.consumer_groups.first.subscription_groups.first.kafka
sg_kafka = Karafka::App.routes.share_groups.first.subscription_groups.first.kafka

# Consumer groups keep the consumer-group specific client settings
assert cg_kafka.key?(:"auto.offset.reset"), cg_kafka.keys
assert_equal false, cg_kafka.fetch(:"enable.auto.offset.store")
assert cg_kafka.key?(:"max.poll.interval.ms"), cg_kafka.keys
assert_equal "cg", cg_kafka.fetch(:"group.id")

# Share groups must not receive any of the share-rejected client settings
assert !sg_kafka.key?(:"auto.offset.reset"), sg_kafka.keys
assert !sg_kafka.key?(:"enable.auto.offset.store"), sg_kafka.keys
assert !sg_kafka.key?(:"max.poll.interval.ms"), sg_kafka.keys
assert !sg_kafka.key?(:"group.instance.id"), sg_kafka.keys

# While still receiving the mode-agnostic defaults and identification
assert_equal "sg", sg_kafka.fetch(:"group.id")
assert sg_kafka.key?(:"client.id"), sg_kafka.keys
assert sg_kafka.key?(:"statistics.interval.ms"), sg_kafka.keys
assert sg_kafka.key?(:"client.software.version"), sg_kafka.keys

# Users define a single kafka settings set (usually globally) and each client scope filters the
# applicable subset - the share scope keeps share-specific keys and filters out consumer-group
# specific ones, the same way producer-only settings are filtered out of consumer configs
share_scoped = Karafka::Setup::AttributesMap.share_group(
  {
    "share.acknowledgement.mode": "explicit",
    "max.poll.records": 100,
    "auto.offset.reset": "earliest",
    "group.instance.id": "s1",
    "bootstrap.servers": "127.0.0.1:9092"
  }
)

assert_equal "explicit", share_scoped.fetch(:"share.acknowledgement.mode")
assert_equal 100, share_scoped.fetch(:"max.poll.records")
assert !share_scoped.key?(:"auto.offset.reset"), share_scoped.keys
assert !share_scoped.key?(:"group.instance.id"), share_scoped.keys

# The legacy .consumer alias keeps working and behaves as .consumer_group
legacy = Karafka::Setup::AttributesMap.consumer({ "auto.offset.reset": "latest" })
assert_equal "latest", legacy.fetch(:"auto.offset.reset")
