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

# We should be able to use latest reference but with eol on, it may end up with nothing

setup_karafka

draw_routes do
  topic DT.topics[0] do
    config(partitions: 2)
    active false
  end
end

2.times do |partition|
  topic = DT.topics[0]

  elements = DT.uuids(20).map { |data| { value: data }.to_json }
  produce_many(topic, elements, partition: partition)
end

offsets = Hash.new { |h, k| h[k] = [] }

iterator = Karafka::Pro::Iterator.new(
  {
    DT.topics[0] => {
      0 => :latest,
      1 => "latest"
    }
  }
)

iterator.each do |message|
  offsets[message.topic][message.partition] ||= []
  offsets[message.topic][message.partition] << message.offset
end

assert offsets[DT.topics[0]].empty?
