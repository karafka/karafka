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

# We should be able to assign to ourselves direct ownership of partitions we are interested in

setup_karafka

DT[:partitions] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:partitions] << partition
  end

  def shutdown
    DT[:shutdowns] << true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 2)
    assign(0, 1)
  end
end

2.times do |i|
  elements = DT.uuids(10)
  produce_many(DT.topic, elements, partition: i)
end

start_karafka_and_wait_until do
  DT[:partitions].size >= 2
end

assert_equal 2, DT[:shutdowns].size
