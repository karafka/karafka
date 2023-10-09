# frozen_string_literal: true

# When rebalance occurs, we should go through all the proper lifecycle events and only for the
# subscription group for which rebalance occurs.
#
# Details should be present and second group should be intact.

setup_karafka do |config|
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes do
  consumer_group :unique_name_a do
    topic DT.topics[0] do
      consumer Consumer
    end
  end

  consumer_group :unique_name_b do
    topic DT.topics[0] do
      consumer Consumer
    end
  end
end

REBALANCE_EVENTS = %w[
  rebalance.partitions_assign
  rebalance.partitions_assigned
  rebalance.partitions_revoke
  rebalance.partitions_revoked
].freeze

REBALANCE_EVENTS.each do |event_name|
  Karafka.monitor.subscribe(event_name) do |event|
    DT[event_name] << [event[:subscription_group_id], Time.now.to_f]
  end
end

# We need a second producer to trigger the rebalances
Thread.new do
  sleep(10)

  10.times do
    consumer = setup_rdkafka_consumer
    consumer.subscribe(DT.topics[0])
    sleep(2)
    consumer.close
    sleep(1)
  end

  DT[:rebalanced] << true
end

start_karafka_and_wait_until do
  produce(DT.topics[0], rand.to_s)
  produce(DT.topics[1], rand.to_s)

  sleep(1)

  DT.key?(:rebalanced)
end

REBALANCE_EVENTS.each do |event_name|
  group_a = []
  group_b = []

  DT[event_name].each do |event|
    if event[0].include?('unique_name_a')
      group_a << event
    else
      group_b << event
    end
  end

  assert group_a.size > group_b.size
  assert_equal group_b.size, 1
end
