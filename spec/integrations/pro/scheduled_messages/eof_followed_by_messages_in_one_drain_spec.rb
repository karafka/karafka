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

# When new schedules keep arriving right after a partition reaches its end, its EOF and the
# messages after it can come in one drain. The EOF is then cleared, but loading should still
# complete on a later EOF, and the past due messages should be dispatched once.

PAST = 10

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

def schedule(id, epoch)
  Karafka::Pro::ScheduledMessages.schedule(
    message: {
      topic: DT.topics[1],
      key: id,
      headers: { "id" => id },
      payload: id,
      partition: 0
    },
    epoch: epoch,
    envelope: {
      topic: DT.topics[0],
      key: id
    }
  )
end

past = Array.new(PAST) do |i|
  proxy = schedule("past-#{i}", Time.now.to_i + 600)
  proxy[:headers]["schedule_target_epoch"] = (Time.now.to_i - 600).to_s
  proxy
end

Karafka.producer.produce_many_sync(past)

Thread.new do
  loop do
    Karafka.producer.produce_many_sync(
      Array.new(5) { schedule(SecureRandom.uuid, Time.now.to_i + 100_000) }
    )

    sleep(0.05)
  end
rescue WaterDrop::Errors::ProducerClosedError
  nil
end

dispatched = []

start_karafka_and_wait_until(sleep: 1) do
  dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 100)
  dispatched.size >= PAST && sleep(2)
end

dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 100)

assert_equal (0...PAST).map { |i| "past-#{i}" }.sort, dispatched.map(&:raw_key).sort
