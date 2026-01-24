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

# Karafka when with VPs should support manual collapsing. After we explicitely collapse VPs, the
# collapse should continue for as long as we wanted

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:state] << collapsed?

    messages.each do
      DT[0] << true
    end

    # Something far in the future, so we're collapsed from start
    collapse_until!(10_000)

    # First run after collapse needs to be false because we should still operate in a non-collapsed
    # mode
    DT[:post_state] << collapsed?
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

assert_equal DT[:state][0], false
assert_equal DT[:post_state][0], false
assert_equal DT[:state].last, true
