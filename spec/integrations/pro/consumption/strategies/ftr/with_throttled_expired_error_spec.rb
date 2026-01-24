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

# When we reach throttling limit and error, we should process again from the errored place
# If throttling went beyond and we should continue, this should not change anything

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    @batches ||= 0
    @batches += 1

    messages.each do |message|
      DT[0] << message.offset
    end

    return if @batches < 2

    DT[:started] = messages.first.offset unless DT.key?(:started)

    # Go beyond throttling wait
    sleep(6)

    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    throttling(
      limit: 5,
      interval: 5_000
    )
  end
end

elements = DT.uuids(100)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT[0].size >= 50
end

started = DT[:started]

assert DT[0].count(started) > 1
# Should not move beyond the failing batch + throttling
assert(DT[0].none? { |element| element > started + 5 })
