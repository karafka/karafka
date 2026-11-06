# frozen_string_literal: true

# An external rdkafka admin instance should serve all admin-based operations without dedicated
# per-operation instances and should stay open and usable afterwards.

setup_karafka

TOPIC = DT.topics[0]

# Derive the brokers from the app config that setup_karafka already resolved so there is one
# source of truth for the cluster location
external_admin = Rdkafka::Config.new(
  "bootstrap.servers": Karafka::App.config.kafka[:"bootstrap.servers"]
).admin

admin = Karafka::Admin.new(external_client: external_admin)

module ClientsTracker
  def admin(...)
    DT[:clients] << :admin

    super
  end

  def consumer(...)
    DT[:clients] << :consumer

    super
  end
end

Rdkafka::Config.prepend(ClientsTracker)

# Topic management via the external admin
admin.create_topic(TOPIC, 2, 1)

info = admin.topic_info(TOPIC)
assert_equal TOPIC, info[:topic_name]
assert_equal 2, info[:partition_count]

# Cluster metadata via the external admin
assert admin.cluster_info.topics.map { |t| t[:topic_name] }.include?(TOPIC)

admin.create_partitions(TOPIC, 3)
assert_equal 3, admin.topic_info(TOPIC)[:partition_count]

# list_offsets based watermark reads via the external admin
produce_many(TOPIC, DT.uuids(5), partition: 0)

watermarks = admin.read_watermark_offsets({ TOPIC => [0] })
assert_equal [0, 5], watermarks.fetch(TOPIC).fetch(0)

# Consumer group offsets are read and changed via the external admin as well
lags = admin.read_lags_with_offsets({ "nonexisting-group" => [TOPIC] })
assert_equal(
  { offset: -1, lag: -1 },
  lags.fetch("nonexisting-group").fetch(TOPIC).fetch(0)
)

admin.seek_consumer_group(DT.group, { TOPIC => { 0 => 2, 1 => Time.now - 60 } })

assert_equal(
  { 0 => { offset: 2, lag: 3 }, 1 => { offset: 0, lag: 0 }, 2 => { offset: -1, lag: -1 } },
  admin.read_lags_with_offsets({ DT.group => [TOPIC] }).fetch(DT.group).fetch(TOPIC)
)

assert DT[:clients].empty?, DT[:clients]

admin.delete_topic(TOPIC)

# The external admin stays fully open and usable afterwards
assert !external_admin.closed?
assert external_admin.metadata.brokers.size >= 1

external_admin.close
