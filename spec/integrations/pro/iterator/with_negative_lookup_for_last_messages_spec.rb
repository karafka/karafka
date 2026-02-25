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

# When using negative lookups, we should get at most what we have requested

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

elements = DT.uuids(20).map { |data| { value: data }.to_json }
produce_many(DT.topic, elements)

# From beginning till the end
iterator = Karafka::Pro::Iterator.new(
  # Give me at most last 5 messages
  { DT.topic => { 0 => -5 } }
)

i = 15
iterator.each do |message|
  assert_equal i, message.offset
  assert_equal message.raw_payload, elements[i]

  message.payload

  i += 1
end

assert_equal i, 20
