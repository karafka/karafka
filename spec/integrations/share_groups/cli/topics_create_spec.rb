# frozen_string_literal: true

# `karafka topics create` should work when share groups (KIP-932) are routed. Share-group topics
# do not carry routing declaratives, so they are created only when declared via the standalone
# declaratives DSL, while consumer-group topics keep their routing-based declarations. A share
# topic created this way should then be consumable by its share group.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

class ShareConsumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

Karafka::App.declaratives.draw do
  topic DT.topics[1] do
    partitions 3
  end
end

draw_routes(create_topics: false) do
  consumer_group DT.groups[0] do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  share_group DT.groups[1] do
    topic DT.topics[1] do
      consumer ShareConsumer
    end

    # Share topic without any declaration - should not be created by the CLI
    topic DT.topics[2] do
      active(false)
      consumer ShareConsumer
    end
  end
end

ARGV.replace(%w[topics create])

Karafka::Cli.start

ARGV.clear

cluster_topics = Karafka::Admin.cluster_info.topics

created = cluster_topics.to_h { |topic| [topic.fetch(:topic_name), topic.fetch(:partition_count)] }

assert_equal 1, created.fetch(DT.topics[0])
assert_equal 3, created.fetch(DT.topics[1])
assert !created.key?(DT.topics[2])

# setup_share_group would try to create the topic again, so we only configure the group offset
# reset here so the already produced records are delivered
admin = Rdkafka::Config.new(
  "bootstrap.servers": Karafka::App.config.kafka.fetch(:"bootstrap.servers")
).admin

admin.incremental_alter_configs(
  [
    {
      resource_type: Rdkafka::Bindings::RD_KAFKA_RESOURCE_GROUP,
      resource_name: DT.groups[1],
      configs: [{ name: "share.auto.offset.reset", value: "earliest", op_type: 0 }]
    }
  ]
).wait(max_wait_timeout_ms: 15_000)

admin.close

elements = DT.uuids(9)
elements.each_with_index do |element, index|
  produce(DT.topics[1], element, partition: index % 3)
end

start_karafka_and_wait_until do
  DT[:accepted].size >= elements.size
end

assert_equal elements.sort, DT[:accepted].sort
