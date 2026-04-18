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

# When running in swarm things should work as expected

setup_karafka do |config|
  # Use a single node — all scheduled messages target partition 0,
  # so only one node does the work. A second node adds rebalancing
  # and shutdown overhead that causes flaky timeouts on macOS CI.
  config.swarm.nodes = 1
  # Scheduled messages consumer has heavy shutdown: flush dispatches, produce tombstones,
  # close producer, close librdkafka handles. On macOS CI this can exceed the default 30s.
  config.shutdown_timeout = 60_000
end

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

schedules = Array.new(10) do |i|
  message = {
    topic: DT.topics[1],
    key: i.to_s,
    headers: { "b" => i.to_s },
    payload: "payload#{i}"
  }

  Karafka::Pro::ScheduledMessages.schedule(
    message: message,
    epoch: Time.now.to_i + 5,
    envelope: { topic: DT.topics[0], partition: 0 }
  )
end

Karafka.producer.produce_many_sync(schedules)

dispatched = nil

start_karafka_and_wait_until(sleep: 1, mode: :swarm) do
  dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 100)

  dispatched.size >= 10
end

assert_equal(
  dispatched.map(&:key),
  (0..9).map(&:to_s),
  dispatched.map { |msg| [msg.offset, msg.key] }
)
