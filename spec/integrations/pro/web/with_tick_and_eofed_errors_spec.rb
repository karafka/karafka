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

# When we use web-ui and error happens during eofed and tick when no offsets were marked as
# consumed, web UI should not fail. It used to fail because it was trying to extract offsets
# from not (yet) existing marking

setup_karafka(allow_errors: %w[consumer.tick.error consumer.eofed.error]) do |config|
  config.kafka[:'enable.partition.eof'] = true
end

setup_web

class Consumer < Karafka::BaseConsumer
  def consume; end

  def eofed
    DT[:eofed] = true

    raise
  end

  def tick
    DT[:tick] = true

    raise
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    periodic(interval: 100)
    eofed(true)
  end
end

start_karafka_and_wait_until do
  DT.key?(:eofed) && DT.key?(:tick)
end

error = Karafka::Admin.read_topic(Karafka::Web.config.topics.errors.name, 0, 1).first.payload

assert_equal error[:details][:first_offset], -1001
assert_equal error[:details][:last_offset], -1001
