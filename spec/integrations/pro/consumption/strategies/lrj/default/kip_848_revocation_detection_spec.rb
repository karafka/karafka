# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Test KIP-848 with Long Running Jobs to ensure that when a rebalance occurs
# during long-running consumption with the new protocol, the consumer is properly
# notified via both #revoked and #revoked? methods

setup_karafka do |config|
  # Use the new consumer protocol (KIP-848)
  config.kafka[:'group.protocol'] = 'consumer'
  # Remove settings that are not compatible with KIP-848
  config.kafka.delete(:'partition.assignment.strategy')
  config.kafka.delete(:'heartbeat.interval.ms')
  config.kafka.delete(:'session.timeout.ms')
  config.kafka[:'max.poll.interval.ms'] = 10_000
end

DT[:started] = Set.new
DT[:revoked] = Set.new
DT[:revoked_method] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:started] << partition

    until DT[:revoked].any?
      sleep(1)

      next unless revoked?

      DT[:revoked] << true
    end
  end

  def revoked
    DT[:revoked_method] << true
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    long_running_job true
  end
end

2.times do |partition|
  produce(DT.topic, "p#{partition}", partition: partition)
end

thread = Thread.new do
  sleep(0.1) until DT[:started].size >= 2

  consumer = Rdkafka::Config.new(
    Karafka::Setup::AttributesMap.consumer(
      'bootstrap.servers': Karafka::App.config.kafka[:'bootstrap.servers'],
      'group.id': Karafka::App.consumer_groups.first.id,
      'group.protocol': 'consumer'
    )
  ).consumer
  consumer.subscribe(DT.topic)
  10.times { consumer.poll(1_000) }
  consumer.close
end

start_karafka_and_wait_until do
  DT[:revoked].any? && DT.key?(:revoked_method)
end

thread.join

# Only one partition should be revoked
assert_equal 1, DT[:revoked].size
assert_equal 1, DT[:revoked_method].size
