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

# When reading committed offsets with a very recent start_time, commits that happened before it
# should not be returned. This verifies the start_time parameter works correctly.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

produce_many(DT.topic, Array.new(10) { rand.to_s })

# Commit offsets
Karafka::Admin.seek_consumer_group(GROUP_ID, { DT.topic => { 0 => 5 } })

# Wait long enough for the commit to be well in the past
sleep(5)

# Read with start_time = now - the commit happened ~5 seconds ago so it should be missed
committed = Karafka::Admin::Recovery.read_committed_offsets(
  GROUP_ID,
  start_time: Time.now
)

assert_equal({}, committed)
