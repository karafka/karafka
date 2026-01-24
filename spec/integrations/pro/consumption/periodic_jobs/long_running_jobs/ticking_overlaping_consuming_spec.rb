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

# When running LRJ and ticking, ticking is not synchronized with LRJ
# (unless synchronized via mutex). This means, that it should be possible to have a long living
# ticking that started when nothing was happening but meanwhile things started.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consume] << Time.now.to_f
  end

  def tick
    start = Time.now.to_f
    produce_many(DT.topic, DT.uuids(1))
    sleep(10)
    DT[:ticks] << (start..Time.now.to_f)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    periodic true
    long_running_job true
  end
end

start_karafka_and_wait_until do
  DT.key?(:ticks)
end

any = DT[:ticks].any? do |time_range|
  DT[:consume].any? do |tick_time|
    time_range.include?(tick_time)
  end
end

# There should be at least one tick parallel to consumption
assert any
