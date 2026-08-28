# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Refreshed end offsets are stored per client, topic and partition. This guards against any leak
# across BOTH dimensions at once: two topics with two partitions each are paused and every one of
# the four topic/partition buckets is fed a different backlog. Each compensated lag must land in
# its own band, so a value leaking to the wrong topic or the wrong partition is caught.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

TOPICS = DT.topics[0..1].freeze
TOPIC_INDEX = TOPICS.each_with_index.to_h.freeze

# Distinct, well-separated backlog per [topic_index, partition]
BACKLOGS = {
  [0, 0] => 5,
  [0, 1] => 15,
  [1, 0] => 25,
  [1, 1] => 35
}.freeze

class Consumer < Karafka::BaseConsumer
  def consume
    topic = messages.metadata.topic
    partition = messages.metadata.partition
    mark_as_consumed!(messages.last)

    key = :"paused_#{topic}_#{partition}"
    return if DT.key?(key)

    pause(messages.last.offset, 1_000_000)
    DT[key] = true
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:emits] << true

  event[:statistics]["topics"].each do |topic, topic_values|
    index = TOPIC_INDEX[topic]
    next unless index

    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:"lag_#{index}_#{partition_name}"] << partition_values["consumer_lag"]
    end
  end
end

draw_topics do
  TOPICS.each { |name| topic(name) { partitions(2) } }
end

draw_routes do
  TOPICS.each { |name| topic(name) { consumer Consumer } }
end

# One seed per topic/partition so each gets consumed once and then paused
TOPICS.each do |name|
  2.times { |partition| produce(name, DT.uuid, partition: partition) }
end

def all_paused?
  TOPICS.all? do |name|
    DT.key?(:"paused_#{name}_0") && DT.key?(:"paused_#{name}_1")
  end
end

# Once everything is paused, feed each bucket its own distinct backlog in a single burst
Thread.new do
  sleep(0.1) until all_paused?

  BACKLOGS.each do |(topic_index, partition), count|
    count.times { produce(TOPICS[topic_index], DT.uuid, partition: partition) }
  end

  DT[:produced] = true
end

start_karafka_and_wait_until do
  # The largest backlog being compensated implies the pause age was crossed and a refresh ran for
  # all of them; fall back on a sample count so a regression fails fast instead of hanging
  compensated = DT[:lag_1_1].max.to_i >= 30 && DT[:lag_0_0].max.to_i >= 2
  compensated || (DT.key?(:produced) && DT[:emits].size >= 50)
end

# Each topic/partition bucket must be compensated to its own backlog, in a band that does not
# overlap any other bucket - so no offset leaked across topics or partitions
assert DT[:lag_0_0].max.between?(2, 10), "topic0/part0 out of band (~5): #{DT[:lag_0_0].max}"
assert DT[:lag_0_1].max.between?(11, 20), "topic0/part1 out of band (~15): #{DT[:lag_0_1].max}"
assert DT[:lag_1_0].max.between?(21, 30), "topic1/part0 out of band (~25): #{DT[:lag_1_0].max}"
assert DT[:lag_1_1].max.between?(31, 44), "topic1/part1 out of band (~35): #{DT[:lag_1_1].max}"
