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

# When offset metadata is stored but a custom forced value is used, the forced on should be used.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"auto.commit.interval.ms"] = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.5)

    DT[:metadata] << offset_metadata(cache: false)

    store_offset_metadata(messages.first.offset.to_s)

    mark_as_consumed(messages.first, "cs")
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management(true)
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:metadata].size >= 10
end

assert_equal ["", "cs"], DT[:metadata].uniq
