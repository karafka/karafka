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

# When we idle all and move on but no more messages for a while, tick should kick in

class Listener
  def on_filtering_seek(_)
    DT[:seeks] << true
  end
end

setup_karafka do |config|
  config.max_messages = 10
end

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end

  # Should never tick because of constant ftr
  def tick
    DT[:ticks] << true
  end
end

class Skipper < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor, :action

  def apply!(messages)
    if @once
      @action = :skip
    else
      @once = true
      @action = :seek
      @cursor = messages.first
      messages.clear
      DT[:done] = true
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
    filter ->(*) { Skipper.new }
    periodic true
  end
end

start_karafka_and_wait_until do
  produce_many(DT.topic, DT.uuids(1)) unless DT.key?(:done)

  # This will hang if something is not working, so no assertions needed
  DT[:ticks].size >= 2
end
