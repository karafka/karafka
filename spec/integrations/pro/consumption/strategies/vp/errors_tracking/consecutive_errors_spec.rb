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

# When using virtual partitions and tracking errors, under collapse they should be present
# collectively from many partitions

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 10
end

E1 = Class.new(StandardError)
E2 = Class.new(StandardError)

class Consumer < Karafka::BaseConsumer
  def consume
    if collapsed?
      DT[:errors_collapsed] << errors_tracker.to_a.dup
    else
      synchronize do
        DT[:switch] << 1

        raise (DT[:switch].size % 2).zero? ? E1 : E2
      end
    end
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next }
    )
    filter VpStabilizer
  end
end

produce_many(DT.topic, DT.uuids(500))

start_karafka_and_wait_until do
  DT[:errors_collapsed].size >= 2
end

assert_equal [10], DT[:errors_collapsed].map(&:size).uniq
assert_equal [E1, E2], DT[:errors_collapsed].map(&:to_a).flatten.map(&:class).uniq.sort_by(&:to_s)
