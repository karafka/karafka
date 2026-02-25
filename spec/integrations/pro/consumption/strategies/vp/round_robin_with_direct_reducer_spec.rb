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

# When using a round-robin partitioner, Karafka should assign messages correctly to utilize all
# VPs. We test two instances to make sure that they operate independently
# Since the default reducer does not work perfectly with all concurrency settings, we can use a
# custom reducer to match the virtual key with partitions 1:1.

class RoundRobinPartitioner
  def initialize
    @cycle = (0...Karafka::App.config.concurrency).cycle
  end

  def call(_message)
    @cycle.next
  end
end

setup_karafka do |config|
  config.concurrency = 11
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[topic.name] << object_id
  end
end

draw_routes do
  2.times do |i|
    consumer_group DT.consumer_groups[i] do
      topic DT.topics[i] do
        consumer Consumer
        filter VpStabilizer
        virtual_partitions(
          partitioner: RoundRobinPartitioner.new,
          reducer: ->(virtual_key) { virtual_key }
        )
      end
    end
  end
end

produce_many(DT.topics[0], DT.uuids(200))
produce_many(DT.topics[1], DT.uuids(200))

# No specs needed, will hang if not working correctly
start_karafka_and_wait_until do
  DT[DT.topics[0]].uniq.size >= 11 && DT[DT.topics[1]].uniq.size >= 11
end
