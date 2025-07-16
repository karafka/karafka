# frozen_string_literal: true

# We should be able to fetch and use info about replication, in sync etc.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active(false)
  end
end

topic_info = Karafka::Admin.cluster_info.topics.find do |t|
  t[:topic_name] == DT.topics[0]
end

replica_counts = []
in_sync_brokers = []

topic_info[:partitions].map do |partition|
  replica_counts << partition[:replica_count]
  in_sync_brokers << partition[:in_sync_replica_brokers]
end

resource = Karafka::Admin::Configs::Resource.new(type: :topic, name: DT.topics[0])
min_insync_replicas_config = -1

Karafka::Admin::Configs.describe(resource).each do |topic_config|
  topic_config.configs.each do |config|
    next unless config.name == 'min.insync.replicas'

    min_insync_replicas_config = config.value.to_i
  end
end

assert_equal replica_counts.min, 1
assert_equal min_insync_replicas_config, 1
assert_equal in_sync_brokers.min, 1
