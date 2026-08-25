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

# The broadest fan-out: two topics with two partitions each, all four paused and all still
# receiving data. Exercises the fetcher building a multi-topic batched request and the compensator
# iterating multiple topics in the statistics hash.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

TOPICS = DT.topics[0..1].freeze

class Consumer < Karafka::BaseConsumer
  def consume
    topic = messages.metadata.topic
    partition = messages.metadata.partition
    mark_as_consumed!(messages.last)

    return if DT.key?(:"paused_#{topic}_#{partition}")

    pause(messages.last.offset, 1_000_000)
    DT[:"paused_#{topic}_#{partition}"] = true
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:emits] << true

  event[:statistics]["topics"].each do |topic, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:"lag_#{topic}_#{partition_name}"] << partition_values["consumer_lag"]
    end
  end
end

draw_topics do
  TOPICS.each { |name| topic(name) { partitions(2) } }
end

draw_routes do
  TOPICS.each do |name|
    topic(name) { consumer Consumer }
  end
end

def produce_round
  TOPICS.each do |name|
    2.times { |partition| produce(name, DT.uuid, partition: partition) }
  end
end

produce_round

def all_paused?
  TOPICS.all? do |name|
    DT.key?(:"paused_#{name}_0") && DT.key?(:"paused_#{name}_1")
  end
end

# The producer stops a few statistics emissions before the server, so it never outlives the
# closed producer on shutdown
Thread.new do
  sleep(0.1) until all_paused?

  loop do
    produce_round
    sleep(0.3)

    break if DT[:emits].size >= 20
  end
end

def lag_keys
  TOPICS.flat_map { |name| [:"lag_#{name}_0", :"lag_#{name}_1"] }
end

start_karafka_and_wait_until do
  DT[:emits].size >= 25
end

# Every topic/partition combination must be compensated
lag_keys.each do |key|
  assert DT[key].max >= 15, "#{key} lag did not grow, max #{DT[key].max}"
end
