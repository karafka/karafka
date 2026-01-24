# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka should trigger a revoked action when a partition is being taken from us
# Initially we should own all the partitions and then after they are taken away, we should get
# back to two (as the last one will be owned by the second consumer).

setup_karafka

DT[:revoked] = []
DT[:pre] = Set.new
DT[:post] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    # Pre rebalance
    if DT[:revoked].empty?
      DT[:pre] << messages.metadata.partition
    # Post rebalance
    else
      DT[:post] << messages.metadata.partition
    end
  end

  # Collect info on all the partitions we have lost
  def revoked
    DT[:revoked] << { messages.metadata.partition => Time.now }
  end
end

draw_routes do
  consumer_group DT.topic do
    topic DT.topic do
      config(partitions: 3)
      consumer Consumer
      manual_offset_management true
    end
  end
end

elements = DT.uuids(100)
elements.each { |data| produce(DT.topic, data, partition: rand(0..2)) }

consumer = setup_rdkafka_consumer

other =  Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)
  consumer.poll(500) until DT.key?(:end)
  consumer.close
end

start_karafka_and_wait_until do
  if DT[:post].empty?
    false
  else
    sleep 2
    true
  end
end

DT[:end] << true

# Rebalance should revoke all 3 partitions
assert_equal 3, DT[:revoked].size

# There should be no extra partitions or anything like that that was revoked
assert (DT[:revoked].flat_map(&:keys) - [0, 1, 2]).empty?

# Before revocation, we should have had all the partitions in our first process
assert_equal [0, 1, 2], DT[:pre].to_a.sort

re_assigned = DT[:post].to_a.sort
# After rebalance we should not get all partitions back as now there are two consumers
assert_not_equal [0, 1, 2], re_assigned
# It may get either one or two partitions back
assert [1, 2].include?(re_assigned.size)

other.join
