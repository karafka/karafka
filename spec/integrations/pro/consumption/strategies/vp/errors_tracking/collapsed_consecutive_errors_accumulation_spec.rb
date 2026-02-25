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

# When using virtual partitions and tracking errors, they under consecutive collapse should grow
# in terms of size

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:errors_collapsed] << errors_tracker.size if collapsed?

    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter VpStabilizer
    virtual_partitions(
      partitioner: ->(_msg) { rand(2) }
    )
  end
end

produce_many(DT.topic, DT.uuids(500))

start_karafka_and_wait_until do
  DT[:errors_collapsed].include?(5)
end

def contains_subsequence?(main_array, sub_array)
  return true if sub_array.empty?

  sub_index = 0
  main_array.each do |element|
    sub_index += 1 if element == sub_array[sub_index]
    return true if sub_index == sub_array.length
  end

  false
end

assert contains_subsequence?(DT[:errors_collapsed], (2..5).to_a)
