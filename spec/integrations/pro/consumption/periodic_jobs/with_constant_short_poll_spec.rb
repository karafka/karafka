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

# When we get constant stream of data on other partition, our unused partition should anyhow tick
# only once every tick interval

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume; end

  def tick
    DT[messages.metadata.partition] << Time.now.to_f
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    periodic true
  end
end

Thread.new do
  loop do
    produce_many(DT.topic, DT.uuids(2), partition: 0)
    sleep(0.1)
  rescue WaterDrop::Errors::ProducerClosedError
    nil
  end
end

start_karafka_and_wait_until do
  DT[1].size >= 5
end

previous = nil

DT[1].each do |time|
  unless previous
    previous = time

    next
  end

  # 5 seconds is the default tick interval and we should not tick more often
  # on an unused but assigned partition
  assert time - previous >= 5

  previous = time
end
