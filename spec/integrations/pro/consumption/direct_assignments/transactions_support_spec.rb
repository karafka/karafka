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

# We should be able to assign what we want and mark offsets in a transaction

setup_karafka do |config|
  config.kafka[:"transactional.id"] = SecureRandom.uuid
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    transaction do
      messages.each { |message| mark_as_consumed(message) }
      produce_async(topic: DT.topic, payload: "1")
    end

    DT[:done] = true

    sleep(2)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # Not a VP case but we want to stabilize number of messages to prevent randomness
    filter ->(*_args) { VpStabilizer.new(10) }
    assign(true)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert fetch_next_offset >= 10, fetch_next_offset
