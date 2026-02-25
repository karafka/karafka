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

# Ticking should work before and after the recovery but not during in the default setup.

setup_karafka(allow_errors: true) do |config|
  config.pause.timeout = 1_000
  config.pause.max_timeout = 1_500
  config.max_wait_time = 100
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    if DT[:errored].size < 5
      DT[:errored] << Time.now.to_f
      raise
    end

    DT[:post_error] << Time.now.to_f
  end

  def tick
    DT[:ticks] << Time.now.to_f
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic interval: 100
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:post_error].size >= 2
end

DT[:ticks].each do |tick|
  assert (tick < DT[:errored].min) || (tick > DT[:post_error].min)
end
