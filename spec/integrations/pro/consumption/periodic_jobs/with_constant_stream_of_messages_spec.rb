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

# When we get constant stream of data, we should not tick

setup_karafka do |config|
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    @consumed = true
    DT[:consume] << true
    sleep(1)
  end

  def tick
    # There can be a case where we tick prior to consume as first poll does not yield any data
    # We do not want to raise then but after first consume with constant stream of data we should
    # never tick
    raise if @consumed
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
  end
end

Thread.new do
  loop do
    produce_many(DT.topic, DT.uuids(2))
    sleep(0.5)
  rescue WaterDrop::Errors::ProducerClosedError
    nil
  end
end

start_karafka_and_wait_until do
  DT[:consume].size >= 10
end
