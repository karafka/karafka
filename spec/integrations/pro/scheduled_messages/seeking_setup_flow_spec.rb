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

# When we define scheduled messages setup, it should have correct offset position configuration
# for offset reset

setup_karafka do |config|
  config.kafka[:'auto.offset.reset'] = 'latest'
end

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end

  scheduled_messages(DT.topics[2])
end

cg = Karafka::App.routes.to_a.first

assert_equal 'earliest', cg.topics[0].kafka[:'auto.offset.reset']
assert_equal 'latest', cg.topics[1].kafka[:'auto.offset.reset']
assert_equal 'earliest', cg.topics[2].kafka[:'auto.offset.reset']
assert_equal 'latest', cg.topics[3].kafka[:'auto.offset.reset']
