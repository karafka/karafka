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

# Inline Insights should ship correct partition and topic details and not mix them
# In Pro despite extra option, should behave same as in OSS when no forced required

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT["#{topic.name}-#{partition}"] << insights
  end
end

draw_routes do
  topic DT.topics[0] do
    config(partitions: 2)
    consumer Consumer
    inline_insights(true)
  end

  topic DT.topics[1] do
    config(partitions: 2)
    consumer Consumer
    inline_insights(true)
  end
end

Thread.new do
  loop do
    [
      DT.topics[0],
      DT.topics[1]
    ].each do |topic|
      2.times do |partition|
        elements = DT.uuids(10)
        produce_many(topic, elements, partition: partition)
      end
    end

    sleep(5)
  end
rescue WaterDrop::Errors::ProducerClosedError
  nil
end

start_karafka_and_wait_until do
  DT.data.size >= 4 && DT.data.all? { |sub| !sub.last.last.empty? }
end

DT.data.each do |key, values|
  _topic, partition = key.split("-")[1..]

  assert_equal partition.to_i, values.last["partition"]
end
