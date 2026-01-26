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

# Karafka should always assign same consumer instance to the same virtual partitioner result.
# In case data from few virtual partitions is merged into one chunk, the partition should always
# stay the same (consistent).

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 100
  config.initial_offset = "earliest"
end

class Consumer < Karafka::BaseConsumer
  def consume
    group = Set.new
    messages.each { |message| group << message.raw_payload }

    DT[:combinations] << [group.to_a, object_id]
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

Thread.new do
  loop do
    produce_many(DT.topic, (0..10).to_a.map(&:to_s).shuffle)
    sleep(0.1)
  rescue WaterDrop::Errors::ProducerClosedError
    break
  end
end

start_karafka_and_wait_until do
  DT[:combinations].size >= 20
end

assignments = {}

DT[:combinations].each do |elements|
  group, consumer = elements

  group.each do |element|
    assignments[element] ||= Set.new
    assignments[element] << consumer
  end
end

assert(assignments.values.map(&:size).all? { _1 == 1 })
