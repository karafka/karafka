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

# When there are no messages at all, we should publish nothing except an empty state

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])
end

state = nil

start_karafka_and_wait_until(sleep: 1) do
  state = Karafka::Admin.read_topic("#{DT.topics[0]}_states", 0, 1).first
end

today = Date.today.strftime("%Y-%m-%d")

assert_equal({ "zlib" => "true" }, state.headers)
assert_equal "1.0.0", state.payload[:schema_version]
assert_equal "loaded", state.payload[:state]
assert_equal({ today.to_sym => 0 }, state.payload[:daily])
assert state.payload[:dispatched_at] > Time.now.to_f - 100
