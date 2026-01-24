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

# Karafka should throttle only the partition that hit limits and not the other one

setup_karafka

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
      DT[:messages_times] << Time.now.to_f
    end
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do
      DT[:non_limited] << Time.now.to_f
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer1
    throttling(
      limit: 2,
      interval: 60_000
    )
  end

  topic DT.topics[1] do
    consumer Consumer2
    throttling(
      limit: 1_000,
      interval: 1_000
    )
  end
end

Karafka.monitor.subscribe 'filtering.throttled' do
  DT[:times] << Time.now.to_f
end

elements = DT.uuids(100)
produce_many(DT.topics[0], elements)

elements = DT.uuids(999)
produce_many(DT.topics[1], elements)

start_karafka_and_wait_until do
  DT[:non_limited].size >= 999
end

assert DT[0].size < 3
