# frozen_string_literal: true

# When subscription groups of one consumer group subscribe to different topics (non-uniform
# subscriptions, classic protocol) and partitions are added to a topic that the group leader does
# not consume, the new partitions should get assigned to the subscription group that consumes it.
#
# librdkafka 2.16.0 group leader tracks metadata only of its own subscription, so it never notices
# the change, no rebalance happens and the new partitions stay unassigned
# (confluentinc/librdkafka#4533).
#
# Subscription group of topic A joins first to become the leader. Subscription group of topic B
# joins only after that.

setup_karafka

Karafka::Connection::ConsumerGroups::Client.prepend(
  Module.new do
    private

    def build_consumer
      if @subscription_group.subscriptions.include?(DT.topics[1])
        sleep(0.1) until DT.key?(:leader_assigned)
      end

      super
    end
  end
)

class LeaderConsumer < Karafka::BaseConsumer
  def consume
    DT[:leader_assigned] = true
  end
end

class FollowerConsumer < Karafka::BaseConsumer
  def consume
    DT[:follower_partitions] << messages.metadata.partition
  end
end

Karafka.monitor.subscribe("rebalance.partitions_assigned") do |event|
  DT[:assignments] << event[:tpl].to_h.transform_values { |tps| tps.map(&:partition) }
end

draw_routes do
  subscription_group :leader do
    topic DT.topics[0] do
      consumer LeaderConsumer
    end
  end

  subscription_group :follower do
    topic DT.topics[1] do
      consumer FollowerConsumer
    end
  end
end

produce(DT.topics[0], "0")
produce(DT.topics[1], "0")

Thread.new do
  sleep(0.1) until DT[:follower_partitions].include?(0)

  Karafka::Admin.create_partitions(DT.topics[1], 3)

  sleep(0.1) until Karafka::Admin.topic_info(DT.topics[1])[:partition_count] == 3

  producer = WaterDrop::Producer.new do |config|
    config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  end

  producer.produce_sync(topic: DT.topics[1], payload: "1", partition: 1)
  producer.produce_sync(topic: DT.topics[1], payload: "2", partition: 2)
  producer.close

  DT[:partitions_added_at] = Time.now
end

# Well past the 5 seconds of `topic.metadata.refresh.interval.ms` Karafka sets by default
start_karafka_and_wait_until do
  DT[:follower_partitions].uniq.size == 3 ||
    (DT.key?(:partitions_added_at) && Time.now - DT[:partitions_added_at] > 60)
end

assert_equal [0, 1, 2], DT[:follower_partitions].uniq.sort, DT[:assignments]
