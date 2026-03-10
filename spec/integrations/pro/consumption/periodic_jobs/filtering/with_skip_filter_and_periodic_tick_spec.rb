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

# When a filter applies :skip action, periodic tick should still fire and
# no partition freeze should occur.

setup_karafka do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] << true
  end

  def tick
    DT[:ticks] << true
  end
end

class SkipFilter < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor, :action

  def apply!(messages)
    if @applied_once
      @action = :skip
    else
      @applied_once = true
      @action = :seek
      @cursor = messages.first
      messages.clear
      DT[:filtered] = true
    end
  end

  def applied?
    true
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter ->(*) { SkipFilter.new }
    periodic true
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1)) unless DT.key?(:filtered)

  # This will hang if the partition freezes, so reaching this is the assertion
  DT[:ticks].size >= 2
end

# Periodic ticks should have fired even with skip filter active
assert DT[:ticks].size >= 2
