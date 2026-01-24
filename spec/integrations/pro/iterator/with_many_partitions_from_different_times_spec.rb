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

# When iterating over different topics/partitions with different times, each should start from
# the expected one.

setup_karafka

draw_routes do
  topic DT.topic do
    config(partitions: 5)
    active false
  end
end

start_times = {}

10.times do |index|
  start_times[index] = Time.now

  5.times do |partition_nr|
    produce(DT.topic, DT.uuid, partition: partition_nr)
  end

  sleep(0.5)
end

partitioned_data = Hash.new { |h, v| h[v] = [] }

partitions = start_times.map { |partition, time| [partition, time] }.first(5).to_h

iterator = Karafka::Pro::Iterator.new({ DT.topic => partitions })

iterator.each do |message|
  partitioned_data[message.partition] << message.offset
end

partitioned_data.each do |partition, data|
  assert_equal (partition..9).to_a, data
end
