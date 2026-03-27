# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka should use the custom poll time when defined

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

elements = DT.uuids(20).map { |data| { value: data }.to_json }
produce_many(DT.topic, elements)

# When we set it to 5 seconds, because we do not limit the flow anyhow, after the last message
# we will wait those 5 seconds
iterator = Karafka::Pro::Iterator.new(DT.topic, max_wait_time: 5_000)

i = 0
time = nil
iterator.each do
  i += 1
  time = Time.now.to_f
end

assert Time.now.to_f - time > 5
assert_equal 20, i
