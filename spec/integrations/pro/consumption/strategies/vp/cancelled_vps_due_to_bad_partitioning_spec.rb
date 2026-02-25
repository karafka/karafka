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

# This PR illustrates how partitioning based on constant payload content basically cancels the
# potential of VPs by creating only single virtual partition.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 100
  config.concurrency = 10
  config.max_wait_time = 1_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    start = Time.now.to_f

    DT[0] << messages.size

    sleep(rand / 10.to_f)

    DT[:ranges] << (start..Time.now.to_f)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.payload["key"] }
    )
  end
end

produce_many(
  DT.topic,
  Array.new(1_000) { { key: "1", data: rand }.to_json }
)

start_karafka_and_wait_until do
  DT[0].sum >= 1_000
end

# Prove that in no cases we overlap because the key is always the same not allowing
# for any work distribution
# If they do not overlap, it means

ranges = DT[:ranges]

ranges.each do |current_range|
  (ranges - [current_range]).each do |compared_range|
    assert_no_overlap(current_range, compared_range)
  end
end
