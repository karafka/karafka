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

# When running on LRJ, ticking should not happen alongside long processing if the long running
# job is running at the moment

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    start = Time.now.to_f
    sleep(10)
    DT[:consume] << (start..Time.now.to_f)
  end

  def tick
    produce_many(DT.topic, DT.uuids(1))
    DT[:ticks] << Time.now.to_f
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic(during_pause: true, interval: 1_000)
    long_running_job true
  end
end

start_karafka_and_wait_until do
  DT[:ticks].size >= 5
end

any = DT[:consume].any? do |time_range|
  DT[:ticks].any? do |tick_time|
    time_range.include?(tick_time)
  end
end

assert !any
