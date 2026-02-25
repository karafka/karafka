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

# We should be able with proper settings

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

produce_many(DT.topic, DT.uuids(50))

topics = { DT.topic => { 0 => true } }

settings = {
  # Setup a custom group that you want to use for offset storage
  "group.id": SecureRandom.uuid,
  # Start from beginning if needed
  "auto.offset.reset": "beginning"
}

iterator = Karafka::Pro::Iterator.new(topics, settings: settings)

count = 0
iterator.each do |message|
  count += 1

  DT[message.partition] << message.offset
  iterator.mark_as_consumed(message)

  iterator.stop if count >= 10
end

iterator = Karafka::Pro::Iterator.new(topics, settings: settings)

count = 0
iterator.each do |message|
  count += 1

  DT[message.partition] << message.offset
  iterator.mark_as_consumed!(message)

  iterator.stop if count >= 10
end

iterator = Karafka::Pro::Iterator.new(topics, settings: settings)

count = 0
iterator.each do |message|
  count += 1

  DT[message.partition] << message.offset
  iterator.mark_as_consumed!(message)

  iterator.stop if count >= 10
end

assert_equal DT[0], (0..29).to_a
