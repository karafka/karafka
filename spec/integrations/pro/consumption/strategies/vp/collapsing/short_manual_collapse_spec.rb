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

# When Karafka collapses for a short time we should regain ability to process in VPs

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    collapse_until!(50)

    messages.each do |message|
      DT[0] << [message.offset, collapsed?]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[0].size >= 100
end

# In theory all up until 50 + 9 (batch edge case) and first could operate in collapse and we check
# that after that VPs are restored

assert_equal false, DT[0].first.last

DT[0].each do |sample|
  next if sample.first < 60

  assert_equal false, sample.last
end
