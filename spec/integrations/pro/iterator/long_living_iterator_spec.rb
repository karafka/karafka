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

# Karafka should have a way to create long living iterators that wait for messages

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

producer_errors = Queue.new
producer_thread = Thread.new do
  loop do
    begin
      produce(DT.topic, "1")
    rescue => e
      producer_errors << e
    end

    sleep(0.02)
  end
end

iterator = Karafka::Pro::Iterator.new(
  { DT.topic => -1 },
  settings: { "enable.partition.eof": false },
  yield_nil: true
)

limit = 100
buffer = []

# Deadline so a stalled producer can never hang this tailing iterator until the suite timeout
deadline = Time.now + 60

iterator.each do |message|
  break if buffer.size >= limit
  break if Time.now > deadline

  buffer << message if message
end

producer_thread.kill

producer_error = producer_errors.empty? ? nil : producer_errors.pop
assert(producer_error.nil?, "Background producer failed: #{producer_error}")

assert_equal(
  limit,
  buffer.size,
  "Expected #{limit} messages before the deadline, tailing iterator only accumulated #{buffer.size}"
)
