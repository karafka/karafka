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

# Refreshed data is stored per client (keyed by the rdkafka client name) and pause tracking is
# scoped per subscription group. Two subscription groups are separate clients, so their
# compensations must stay independent. Each subscription group consumes its own topic, paused, at a
# very different backlog; the compensated lags must each reflect their own subscription group, with
# no leak across clients.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

TOPICS = DT.topics[0..1].freeze
TOPIC_INDEX = TOPICS.each_with_index.to_h.freeze
BACKLOGS = { 0 => 30, 1 => 6 }.freeze

class Consumer < Karafka::BaseConsumer
  def consume
    topic = messages.metadata.topic
    mark_as_consumed!(messages.last)

    return if DT.key?(:"paused_#{topic}")

    pause(messages.last.offset, 1_000_000)
    DT[:"paused_#{topic}"] = true
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  DT[:emits] << true

  event[:statistics]["topics"].each do |topic, topic_values|
    index = TOPIC_INDEX[topic]
    next unless index

    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:"lag_#{index}"] << partition_values["consumer_lag"]
    end
  end
end

# Each topic lives in its own subscription group, i.e. its own client / connection
draw_routes do
  subscription_group "fast" do
    topic(TOPICS[0]) { consumer Consumer }
  end

  subscription_group "slow" do
    topic(TOPICS[1]) { consumer Consumer }
  end
end

TOPICS.each { |name| produce(name, DT.uuid) }

Thread.new do
  sleep(0.1) until DT.key?(:"paused_#{TOPICS[0]}") && DT.key?(:"paused_#{TOPICS[1]}")

  BACKLOGS.each do |index, count|
    count.times { produce(TOPICS[index], DT.uuid) }
  end

  DT[:produced] = true
end

start_karafka_and_wait_until do
  compensated = DT[:lag_0].max.to_i >= 20 && DT[:lag_1].max.to_i >= 2
  compensated || (DT.key?(:produced) && DT[:emits].size >= 50)
end

# The busy subscription group is compensated to its large backlog ...
assert DT[:lag_0].max >= 20, "subscription group 0 not compensated, got max #{DT[:lag_0].max}"
# ... the quiet one to its own small backlog - not blended up with the other client's value
assert DT[:lag_1].max.between?(2, 12), "subscription group 1 leaked another client's lag, got max #{DT[:lag_1].max}"
