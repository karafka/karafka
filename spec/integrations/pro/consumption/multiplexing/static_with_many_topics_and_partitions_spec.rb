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

# We should be able to have static group membership with cooperative on many topics and partitions
# with multiplexing starting with 1 without any issues.

setup_karafka do |config|
  config.concurrency = 10
  config.kafka[:'group.instance.id'] = SecureRandom.uuid
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

DT[:used] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:used] << "#{topic.name}-#{partition}"
  end
end

draw_routes do
  subscription_group do
    multiplexing(max: 2, boot: 1, min: 1)

    10.times do |i|
      topic DT.topics[i] do
        config(partitions: 10)
        consumer Consumer
        non_blocking_job true
        manual_offset_management true
      end
    end
  end
end

10.times do |i|
  10.times do |j|
    produce_many(DT.topics[i], DT.uuids(1), partition: j)
  end
end

start_karafka_and_wait_until do
  DT[:used].size >= 100
end
